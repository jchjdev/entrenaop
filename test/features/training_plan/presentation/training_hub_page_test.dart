import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _goal = PreparationGoal(
  id: 'g',
  program: PreparationProgram(
    id: 'p',
    name: 'Preparación actual',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
final _week = DateTime(2026, 10, 5);
AdaptiveProgramProgress _program(
  String status, {
  String id = 'g',
  String? name,
}) => AdaptiveProgramProgress(
  goalId: id,
  name: name ?? 'Preparación actual',
  status: status,
  message: 'Mensaje real del programa.',
);
PreparationOverview _overview({
  List<PreparationGoal> goals = const [_goal],
  List<AdaptiveProgramProgress> programs = const [],
  List<ScheduledWorkout> workouts = const [],
}) => PreparationOverview(
  assessments: const [],
  preferences: null,
  goals: goals,
  weekStart: _week,
  weeklyWorkouts: workouts,
  programs: programs,
);
ScheduledWorkout _workout(
  String id,
  ScheduledWorkoutStatus status, {
  bool extra = false,
}) => ScheduledWorkout(
  id: id,
  templateId: 't',
  templateName: 'Sesión $id',
  templateVersion: 1,
  scheduledDate: _week.add(const Duration(days: 2)),
  source: extra
      ? ScheduledWorkoutSource.user
      : ScheduledWorkoutSource.algorithm,
  preparationGoalId: extra ? null : 'g',
  status: status,
  executionId: status == ScheduledWorkoutStatus.inProgress
      ? 'execution-$id'
      : null,
);

void main() {
  Future<({GoRouter router, DashboardCubit cubit, _Overview source})> mount(
    WidgetTester tester,
    PreparationOverview data, {
    double width = 360,
    double height = 900,
    double textScale = 1,
    bool failInitially = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final source = _Overview(data)..fail = failInitially;
    final cubit = DashboardCubit(getOverview: source);
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan',
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, _) =>
              BlocProvider.value(value: cubit, child: const TrainingHubPage()),
        ),
        for (final path in [
          '/plan/week',
          '/plan/week/active/:id',
          '/plan/goal',
          '/plan/goal/:id',
          '/plan/goal/:id/training',
          '/profile/preferences',
          '/plan/goal/:id/troop-assessment',
          '/plan/goal/:id/periodic-assessment',
          '/plan/goal/:id/program-assessment',
        ])
          GoRoute(
            path: path,
            builder: (_, state) =>
                Scaffold(body: Text('Destino: ${state.uri}')),
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
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, cubit: cubit, source: source);
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'primer acceso separa preparación de programa y conserva agenda manual',
    (tester) async {
      await mount(tester, _overview(goals: []));
      expect(find.text('No hay programa en curso'), findsOneWidget);
      expect(find.text('Define qué pruebas estás preparando'), findsOneWidget);
      expect(find.textContaining('PROGRAMA EN CURSO'), findsNothing);
      expect(find.text('Abrir biblioteca'), findsNothing);
      expect(find.text('Crear y gestionar sesiones'), findsNothing);
      await show(tester, find.text('Abrir mi semana'));
      await tester.tap(find.text('Abrir mi semana'));
      await tester.pumpAndSettle();
      expect(find.text('Destino: /plan/week'), findsOneWidget);
    },
  );

  testWidgets(
    'programa real, recuentos y estados separados sin anunciar borradores activos',
    (tester) async {
      final others = ['draft', 'paused', 'complete']
          .map(
            (status) => PreparationGoal(
              id: status,
              program: PreparationProgram(
                id: status,
                name: 'Preparación $status',
                kind: PreparationProgramKind.internalAssessment,
              ),
            ),
          )
          .toList();
      await mount(
        tester,
        _overview(
          goals: [_goal, ...others],
          programs: [
            _program('training'),
            for (final status in ['draft', 'paused', 'complete'])
              _program(status, id: status),
          ],
          workouts: [
            _workout('completed', ScheduledWorkoutStatus.completed),
            _workout('extra', ScheduledWorkoutStatus.planned, extra: true),
            _workout('planned', ScheduledWorkoutStatus.planned),
            _workout('skipped', ScheduledWorkoutStatus.skipped),
            _workout('abandoned', ScheduledWorkoutStatus.abandoned),
          ],
        ),
      );
      expect(find.text('PROGRAMA EN CURSO · En curso'), findsOneWidget);
      expect(find.text('1 completadas · 2 pendientes'), findsOneWidget);
      expect(find.text('Sesión skipped'), findsNothing);
      expect(find.text('Sesión abandoned'), findsNothing);
      for (final label in ['Por configurar', 'Pausada', 'Finalizada']) {
        await show(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['training', 'needs_review', 'paused']) {
    testWidgets('$status abre el programa directamente sin pasar por gestión', (
      tester,
    ) async {
      final result = await mount(
        tester,
        _overview(programs: [_program(status)]),
      );
      final label = status == 'training'
          ? 'Ver mi programa'
          : status == 'needs_review'
          ? 'Revisar lo pendiente'
          : 'Retomar mi programa';
      if (status == 'paused') {
        expect(find.text('No hay programa en curso'), findsOneWidget);
        expect(find.textContaining('PROGRAMA EN CURSO'), findsNothing);
      }
      await show(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Destino: /plan/goal/g/training'), findsOneWidget);
      result.router.pop();
      await tester.pumpAndSettle();
      expect(result.source.calls, 2); // Carga inicial y una sola al regresar.
    });
  }

  testWidgets(
    'ver sesión conserva fecha e identidad; retomar usa la ejecución existente',
    (tester) async {
      final result = await mount(
        tester,
        _overview(
          programs: [_program('training')],
          workouts: [
            _workout('planned', ScheduledWorkoutStatus.planned),
            _workout('in-progress', ScheduledWorkoutStatus.inProgress),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.text('Sesión in-progress')).dy,
        lessThan(tester.getTopLeft(find.text('Sesión planned')).dy),
      );
      await show(tester, find.text('Retomar sesión'));
      await tester.tap(find.text('Retomar sesión'));
      await tester.pumpAndSettle();
      expect(
        find.text('Destino: /plan/week/active/execution-in-progress'),
        findsOneWidget,
      );
      result.router.pop();
      await tester.pumpAndSettle();
      await show(tester, find.text('Ver sesión'));
      await tester.tap(find.text('Ver sesión'));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/week');
      expect(result.router.state.uri.queryParameters, {
        'date': '2026-10-07',
        'session': 'planned',
      });
    },
  );

  testWidgets(
    'volver conserva scroll y un fallo conserva el resumen con reintento',
    (tester) async {
      final result = await mount(
        tester,
        _overview(programs: [_program('training')]),
      );
      await show(tester, find.text('Editar disponibilidad y material'));
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await tester.tap(find.text('Editar disponibilidad y material'));
      await tester.pumpAndSettle();
      result.source.fail = true;
      result.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Preparación actual'), findsOneWidget);
      expect(find.text('Reintentar cargar Mi plan'), findsOneWidget);
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(after, before);
      result.source.fail = false;
      result.source.data = _overview(programs: [_program('needs_review')]);
      await tester.scrollUntilVisible(
        find.text('Reintentar cargar Mi plan'),
        -250,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar cargar Mi plan'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar cargar Mi plan'), findsNothing);
      expect(
        find.text('PROGRAMA EN CURSO · Revisión pendiente'),
        findsOneWidget,
      );
      expect(result.source.calls, 3);
    },
  );

  testWidgets('fallo inicial permite volver a consultar', (tester) async {
    final result = await mount(tester, _overview(), failInitially: true);
    expect(find.text('No hay programa en curso'), findsNothing);
    result.source.fail = false;
    await tester.tap(find.text('Reintentar cargar Mi plan'));
    await tester.pumpAndSettle();
    expect(find.text('No hay programa en curso'), findsOneWidget);
  });

  for (final (programId, segment) in [
    (PreparationProgramIds.armedForcesTroopEntry, 'troop-assessment'),
    (PreparationProgramIds.fasPeriodicAssessment, 'periodic-assessment'),
    ('generic', 'program-assessment'),
  ]) {
    testWidgets('el siguiente paso mantiene la evaluación de $programId', (
      tester,
    ) async {
      final goal = PreparationGoal(
        id: 'g',
        program: PreparationProgram(
          id: programId,
          name: 'Pruebas',
          kind: PreparationProgramKind.internalAssessment,
        ),
      );
      final result = await mount(tester, _overview(goals: [goal]));
      await show(tester, find.text('Registrar marcas'));
      await tester.tap(find.text('Registrar marcas'));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/goal/g/$segment');
    });
  }

  testWidgets('más de tres pendientes conservan acceso a la semana completa', (
    tester,
  ) async {
    final result = await mount(
      tester,
      _overview(
        programs: [_program('training')],
        workouts: [
          for (final id in ['1', '2', '3', '4'])
            _workout(id, ScheduledWorkoutStatus.planned),
        ],
      ),
    );
    expect(find.text('0 completadas · 4 pendientes'), findsOneWidget);
    expect(find.text('Sesión 4'), findsNothing);
    final action = find.text('Ver las 4 sesiones pendientes en Mi semana');
    await show(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(result.router.state.uri.path, '/plan/week');
  });

  for (final width in [320.0, 1100.0]) {
    for (final status in [
      'training',
      'needs_review',
      'paused',
      'draft',
      'complete',
    ]) {
      testWidgets('Mi plan $status no desborda a $width px con texto 2×', (
        tester,
      ) async {
        await mount(
          tester,
          _overview(
            programs: [_program(status)],
            workouts: [_workout('larga', ScheduledWorkoutStatus.planned)],
          ),
          width: width,
          height: 480,
          textScale: 2,
        );
        await show(tester, find.text('Editar disponibilidad y material'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.data);
  PreparationOverview data;
  bool fail = false;
  int calls = 0;
  @override
  Future<PreparationOverview> call() async {
    calls++;
    if (fail) throw StateError('offline');
    return data;
  }
}
