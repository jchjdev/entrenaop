import 'dart:async';

import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_state.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/workout_schedule_page.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  for (final width in [390.0, 800.0, 1200.0]) {
    testWidgets('los siete días ocupan el ancho de Mi semana a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _cubit(_FakeScheduleRepository(), _FakeWorkoutRepository());
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        initialLocation: '/plan/week',
        routes: [
          GoRoute(
            path: '/plan/week',
            builder: (_, _) => RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: BlocProvider.value(
                value: cubit,
                child: const WorkoutSchedulePage(),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      Finder day(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      final monday = tester.getRect(day('LUN'));
      final sunday = tester.getRect(day('DOM'));
      final contentWidth = (width - 32).clamp(0.0, 920.0);
      expect(sunday.right - monday.left, closeTo(contentWidth, .1));
      expect(monday.width, closeTo(sunday.width, .1));
      await capturePerformanceWidget(tester, 'semana-ancho-${width.toInt()}');
      await tester.tap(day('DOM'));
      await tester.pumpAndSettle();
      expect(cubit.state.selectedDay, cubit.state.weekEnd);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'los días siguen accesibles con texto ampliado en pantalla estrecha',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _cubit(_FakeScheduleRepository(), _FakeWorkoutRepository());
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        initialLocation: '/plan/week',
        routes: [
          GoRoute(
            path: '/plan/week',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const WorkoutSchedulePage(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final strip = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      await tester.drag(strip, const Offset(-700, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DOM'));
      await tester.pumpAndSettle();
      expect(cubit.state.selectedDay, cubit.state.weekEnd);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'una semana antigua no reemplaza la nueva al terminar fuera de orden',
    () async {
      final pending = Completer<List<ScheduledWorkout>>();
      final repository = _FakeScheduleRepository();
      repository.onRange = (start, end) =>
          start == DateTime(2026, 9, 21) ? pending.future : Future.value([]);
      final cubit = _cubit(repository, _FakeWorkoutRepository());
      final oldLoad = cubit.load();
      await Future<void>.delayed(Duration.zero);
      await cubit.changeWeek(1);
      expect(cubit.state.weekStart, DateTime(2026, 9, 28));
      expect(cubit.state.selectedDay, DateTime(2026, 9, 28));
      pending.complete([_scheduled()]);
      await oldLoad;
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.status, WorkoutScheduleStatus.ready);
      cubit.selectDay(DateTime(2026, 10, 1));
      await cubit.load();
      expect(cubit.state.selectedDay, DateTime(2026, 10, 1));
      await cubit.close();
      await cubit.load();
    },
  );
  testWidgets(
    'Mi semana muestra solo el programa en curso y sigue el cambio al retomar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final programs = _Programs()
        ..results = [
          _program('tropa', 'Ingreso · Tropa', 'draft'),
          _program('paused', 'Preparación pausada', 'paused'),
          _program('finished', 'Preparación terminada', 'complete'),
          _program('fas', 'Evaluación FAS', 'training'),
        ];
      final cubit = _cubit(
        _FakeScheduleRepository(items: [_scheduled()]),
        _FakeWorkoutRepository(),
        programs: programs,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        initialLocation: '/plan/week',
        routes: [
          GoRoute(
            path: '/plan/week',
            builder: (_, _) => RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: BlocProvider.value(
                value: cubit,
                child: const WorkoutSchedulePage(),
              ),
            ),
          ),
          GoRoute(
            path: '/plan/goal/:id/training',
            builder: (_, state) =>
                Scaffold(body: Text('Programa ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Evaluación FAS'), findsOneWidget);
      expect(find.text('Ingreso · Tropa'), findsNothing);
      expect(find.text('Preparación pausada'), findsNothing);
      expect(find.text('Preparación terminada'), findsNothing);
      expect(find.text('Empezar mi programa'), findsNothing);
      expect(find.text('Retomar mi programa'), findsNothing);
      // Los entrenamientos extra siguen en la agenda del programa en curso.
      expect(cubit.state.selectedItems.single.id, 'scheduled-1');
      await capturePerformanceWidget(tester, 'agenda-solo-programa-en-curso');

      programs.results = [
        _program('fas', 'Evaluación FAS', 'paused'),
        _program('tropa', 'Ingreso · Tropa', 'needs_review'),
      ];
      await cubit.load();
      await tester.pumpAndSettle();
      expect(find.text('Evaluación FAS'), findsNothing);
      expect(find.text('Ingreso · Tropa'), findsOneWidget);
      await tester.tap(find.text('Revisar lo pendiente'));
      await tester.pumpAndSettle();
      expect(find.text('Programa tropa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preparaciones guardadas sin programa en curso no prometen continuidad',
    (tester) async {
      final programs = _Programs()
        ..results = [
          _program('tropa', 'Ingreso · Tropa', 'draft'),
          _program('fas', 'Evaluación FAS', 'paused'),
          _program('finished', 'Preparación terminada', 'complete'),
        ];
      final cubit = _cubit(
        _FakeScheduleRepository(items: []),
        _FakeWorkoutRepository(),
        programs: programs,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        initialLocation: '/plan/week',
        routes: [
          GoRoute(
            path: '/plan/week',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const WorkoutSchedulePage(),
            ),
          ),
          GoRoute(
            path: '/plan/goal',
            builder: (_, _) => const Scaffold(body: Text('Mis preparaciones')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Ingreso · Tropa'), findsNothing);
      expect(find.text('Evaluación FAS'), findsNothing);
      expect(find.text('Preparación terminada'), findsNothing);
      expect(
        find.textContaining('Sigue las sesiones de tu programa'),
        findsNothing,
      );
      expect(
        find.textContaining('No tienes un programa en curso'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Ver mis preparaciones'));
      await tester.tap(find.text('Ver mis preparaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Mis preparaciones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'agenda futura muestra continuidad, recupera estado y no ofrece fabricar semanas',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final programs = _Programs()
        ..results = [
          AdaptiveProgramProgress(
            goalId: 'g',
            name: 'Mi preparación',
            status: 'training',
            message: 'La siguiente semana se preparará automáticamente a partir del 05/10.',
            currentWeek: DateTime(2026, 10, 5),
            nextGenerationOn: DateTime(2026, 10, 5),
          ),
        ];
      final cubit = WorkoutScheduleCubit(
        programs: programs,
        getSchedule: GetWorkoutScheduleUseCase(
          _FakeScheduleRepository(items: []),
        ),
        scheduleWorkout: ScheduleWorkoutUseCase(_FakeScheduleRepository()),
        rescheduleWorkout: RescheduleWorkoutUseCase(_FakeScheduleRepository()),
        cancelWorkout: CancelScheduledWorkoutUseCase(_FakeScheduleRepository()),
        startWorkout: StartScheduledWorkoutUseCase(_FakeScheduleRepository()),
        getPublicWorkouts: GetPublicWorkoutsUseCase(_FakeWorkoutRepository()),
        getPersonalWorkouts: GetPersonalWorkoutsUseCase(
          _FakeWorkoutRepository(),
        ),
        initialDate: DateTime(2026, 10, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(programs.refreshes, 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: BlocProvider.value(
              value: cubit,
              child: const WorkoutSchedulePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no tienes que crearla'), findsOneWidget);
      expect(find.text('Preparar esta semana'), findsNothing);
      expect(find.text('Elegir mi preparación'), findsNothing);
      expect(tester.takeException(), isNull);
      await capturePerformanceWidget(tester, 'agenda-programa-activo');
      await cubit.changeWeek(1);
      expect(programs.refreshes, 2);
      expect(cubit.state.programs.single.goalId, 'g');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ir a mis entrenamientos'));
      await tester.tap(find.text('Ir a mis entrenamientos'));
      await tester.pumpAndSettle();
      expect(cubit.state.weekStart, DateTime(2026, 10, 5));
      expect(programs.refreshes, 3);
    },
  );
  testWidgets('sin programa se ofrece el alta y no fabricar una semana', (
    tester,
  ) async {
    final cubit = _cubit(
      _FakeScheduleRepository(items: []),
      _FakeWorkoutRepository(),
    );
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan/week',
      routes: [
        GoRoute(
          path: '/plan/week',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const WorkoutSchedulePage(),
          ),
        ),
        GoRoute(
          path: '/plan/goal',
          builder: (_, state) => Scaffold(
            body: Text('Preparación ${state.uri.queryParameters['week']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Elegir mi preparación'));
    await tester.tap(find.text('Elegir mi preparación'));
    await tester.pumpAndSettle();
    expect(find.text('Preparación null'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'una sesión completada abre su resultado en una pantalla estrecha',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = ScheduledWorkout(
        id: 'scheduled-completed',
        templateId: 'algorithm-template',
        templateName: 'Carrera · fácil',
        templateVersion: 1,
        scheduledDate: DateTime(2026, 9, 23),
        source: ScheduledWorkoutSource.algorithm,
        status: ScheduledWorkoutStatus.completed,
        preparationGoalId: 'goal-1',
        executionId: 'execution-1',
      );
      final cubit = _cubit(
        _FakeScheduleRepository(items: [item]),
        _FakeWorkoutRepository(),
      );
      await cubit.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Inicio')),
          ),
          GoRoute(
            path: '/plan/week',
            builder: (context, state) => BlocProvider.value(
              value: cubit,
              child: const WorkoutSchedulePage(),
            ),
          ),
          GoRoute(
            path: '/assessment/history/workouts/:id',
            builder: (context, state) =>
                Scaffold(body: Text('Resultado ${state.pathParameters['id']}')),
          ),
        ],
        initialLocation: '/plan/week',
      );
      addTearDown(router.dispose);
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('DOM')).right, lessThan(360));
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado execution-1'), findsOneWidget);
    },
  );
  test(
    'carga la semana natural y separa biblioteca de sesiones propias',
    () async {
      final scheduleRepository = _FakeScheduleRepository(items: [_scheduled()]);
      final workoutRepository = _FakeWorkoutRepository();
      final cubit = _cubit(scheduleRepository, workoutRepository);

      await cubit.load();

      expect(scheduleRepository.lastStart, DateTime(2026, 9, 21));
      expect(scheduleRepository.lastEnd, DateTime(2026, 9, 27));
      expect(cubit.state.status, WorkoutScheduleStatus.ready);
      expect(cubit.state.selectedItems, [_scheduled()]);
      expect(cubit.state.publicTemplates.single.id, 'public-1');
      expect(cubit.state.personalTemplates.single.id, 'personal-1');
      await cubit.close();
    },
  );

  test(
    'al programar recarga la agenda sin perder el día seleccionado',
    () async {
      final scheduleRepository = _FakeScheduleRepository();
      final workoutRepository = _FakeWorkoutRepository();
      final cubit = _cubit(scheduleRepository, workoutRepository);
      await cubit.load();
      cubit.selectDay(DateTime(2026, 9, 24));

      final success = await cubit.schedule(workoutRepository.personal.single);

      expect(success, isTrue);
      expect(scheduleRepository.scheduledTemplateId, 'personal-1');
      expect(scheduleRepository.scheduledDate, DateTime(2026, 9, 24));
      expect(cubit.state.selectedDay, DateTime(2026, 9, 24));
      await cubit.close();
    },
  );

  test('abre la semana y el día solicitados desde Inicio', () {
    final cubit = WorkoutScheduleCubit(
      programs: _Programs(),
      getSchedule: GetWorkoutScheduleUseCase(_FakeScheduleRepository()),
      scheduleWorkout: ScheduleWorkoutUseCase(_FakeScheduleRepository()),
      rescheduleWorkout: RescheduleWorkoutUseCase(_FakeScheduleRepository()),
      cancelWorkout: CancelScheduledWorkoutUseCase(_FakeScheduleRepository()),
      startWorkout: StartScheduledWorkoutUseCase(_FakeScheduleRepository()),
      getPublicWorkouts: GetPublicWorkoutsUseCase(_FakeWorkoutRepository()),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(_FakeWorkoutRepository()),
      initialDate: DateTime(2026, 10, 4),
      now: () => DateTime(2026, 9, 23),
    );
    addTearDown(cubit.close);

    expect(cubit.state.weekStart, DateTime(2026, 9, 28));
    expect(cubit.state.selectedDay, DateTime(2026, 10, 4));
  });
}

WorkoutScheduleCubit _cubit(
  WorkoutScheduleRepository scheduleRepository,
  WorkoutRepository workoutRepository, {
  _Programs? programs,
}) => WorkoutScheduleCubit(
  programs: programs ?? _Programs(),
  getSchedule: GetWorkoutScheduleUseCase(scheduleRepository),
  scheduleWorkout: ScheduleWorkoutUseCase(scheduleRepository),
  rescheduleWorkout: RescheduleWorkoutUseCase(scheduleRepository),
  cancelWorkout: CancelScheduledWorkoutUseCase(scheduleRepository),
  startWorkout: StartScheduledWorkoutUseCase(scheduleRepository),
  getPublicWorkouts: GetPublicWorkoutsUseCase(workoutRepository),
  getPersonalWorkouts: GetPersonalWorkoutsUseCase(workoutRepository),
  now: () => DateTime(2026, 9, 23, 18),
);

AdaptiveProgramProgress _program(String id, String name, String status) =>
    AdaptiveProgramProgress(
      goalId: id,
      name: name,
      status: status,
      message: 'Estado de $name',
      currentWeek: DateTime(2026, 9, 21),
    );

class _Programs implements PreparationTrainingRepository {
  int refreshes = 0;
  List<AdaptiveProgramProgress> results = [];
  @override
  Future<List<AdaptiveProgramProgress>> refreshPrograms() async {
    refreshes++;
    return results;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ScheduledWorkout _scheduled() => ScheduledWorkout(
  id: 'scheduled-1',
  templateId: 'public-1',
  templateName: 'Fuerza de tren superior',
  templateVersion: 1,
  scheduledDate: DateTime(2026, 9, 23),
  source: ScheduledWorkoutSource.library,
  status: ScheduledWorkoutStatus.planned,
);

class _FakeScheduleRepository implements WorkoutScheduleRepository {
  _FakeScheduleRepository({this.items = const []});

  final List<ScheduledWorkout> items;
  DateTime? lastStart;
  DateTime? lastEnd;
  String? scheduledTemplateId;
  DateTime? scheduledDate;
  Future<List<ScheduledWorkout>> Function(DateTime, DateTime)? onRange;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async {
    lastStart = start;
    lastEnd = end;
    return onRange == null ? items : await onRange!(start, end);
  }

  @override
  Future<String> schedule(
    String templateId,
    DateTime date, {
    String? time,
  }) async {
    scheduledTemplateId = templateId;
    scheduledDate = date;
    return 'scheduled-2';
  }

  @override
  Future<void> cancel(String scheduledId) async {}

  @override
  Future<void> reschedule(
    String scheduledId,
    DateTime date, {
    String? time,
  }) async {}

  @override
  Future<String> start(String scheduledId) async => 'execution-1';
}

class _FakeWorkoutRepository implements WorkoutRepository {
  final public = const [
    WorkoutTemplateSummary(
      id: 'public-1',
      name: 'Fuerza de tren superior',
      description: null,
      estimatedDurationMinutes: 35,
      origin: WorkoutTemplateOrigin.system,
      version: 1,
    ),
  ];
  final personal = const [
    WorkoutTemplateSummary(
      id: 'personal-1',
      name: 'Mi sesión de dominadas',
      description: null,
      estimatedDurationMinutes: 25,
      origin: WorkoutTemplateOrigin.user,
      version: 2,
    ),
  ];

  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => public;

  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => personal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
