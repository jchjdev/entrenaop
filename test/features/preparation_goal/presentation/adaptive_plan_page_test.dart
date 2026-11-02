import 'dart:async';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_path.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/published_adaptive_week_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/adaptive_plan_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/adaptive_plan_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/performance_visual_review.dart';
import '../../../support/pro_access_fixture.dart';

final _latest = DateTime(2026, 11, 2);
final _previous = DateTime(2026, 10, 26);
const _goal = PreparationGoal(
  id: 'goal',
  program: PreparationProgram(
    id: 'fas',
    name: 'Preparación FAS',
    kind: PreparationProgramKind.internalAssessment,
  ),
);

PreparationTrainingData _setup({
  String status = 'training',
  bool phases = false,
}) => PreparationTrainingData(
  catalog: const [],
  context: null,
  runningContext: null,
  references: const [],
  objectives: const [],
  relations: const [],
  publishedWeeks: [_previous, _latest],
  programName: 'Preparación FAS',
  programState: {
    'status': status,
    'message': 'Estado publicado por el servidor.',
  },
  programPath: phases
      ? const AdaptiveProgramPath(
          objectives: [
            ProgramObjectivePhase(
              code: 'base',
              name: 'Base',
              exerciseName: 'Dominadas',
              purpose: 'Preparar la técnica.',
              nextReview: 'Según resultados.',
            ),
          ],
        )
      : const AdaptiveProgramPath(),
);

ScheduledWorkout _workout({
  String id = 'session',
  String goal = 'goal',
  ScheduledWorkoutSource source = ScheduledWorkoutSource.algorithm,
  ScheduledWorkoutStatus status = ScheduledWorkoutStatus.planned,
}) => ScheduledWorkout(
  id: id,
  templateId: 'template',
  templateName: 'Entrenamiento pautado',
  templateVersion: 4,
  scheduledDate: _latest,
  source: source,
  status: status,
  preparationGoalId: goal,
  executionId: status == ScheduledWorkoutStatus.completed ? 'execution' : null,
);

PreparationDetail _detail(
  DateTime week, {
  List<ScheduledWorkout> workouts = const [],
}) => PreparationDetail(
  goal: _goal,
  weekStart: week,
  weekEnd: week.add(const Duration(days: 6)),
  weeklyWorkouts: workouts,
);

final _published = PublishedAdaptiveWeek(
  preparationDecision: {
    'sessions': [
      {
        'date': '2026-11-02',
        'minutes': 35,
        'name': 'Fuerza anterior conservada',
        'kind': 'performance',
        'warm_up_seconds': 420,
        'warm_up_instructions': 'Movilidad pautada en esta versión.',
        'work': [
          {
            'name': 'Dominadas asistidas',
            'reason': 'Motivo de la pauta guardada.',
            'dose': {
              'targets': [5, 5],
              'rest_seconds': 90,
              'task': {'measurement': 'REPS', 'target_rir': 2},
            },
          },
        ],
      },
    ],
  },
  runningDecision: {
    'sessions': [
      {
        'date': '2026-11-04',
        'minutes': 25,
        'name': 'Carrera anterior conservada',
        'description': 'Carrera suave pautada.',
      },
    ],
  },
);

void main() {
  setUpAll(loadReviewFont);

  test('consulta la última pauta y filtra sesiones de otros recorridos, sin escribir', () async {
    final training = _Training(_setup());
    final reader = _Published();
    final detail = _Detail(
      (_, week, _) async => _detail(
        week,
        workouts: [
          _workout(),
          _workout(id: 'other', goal: 'other'),
          _workout(id: 'coach', source: ScheduledWorkoutSource.coach),
        ],
      ),
    );
    final cubit = AdaptivePlanCubit(
      goalId: 'goal',
      repository: training,
      getDetail: detail,
      publishedRepository: reader,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.week, _latest);
    expect(cubit.state.workouts.map((item) => item.id), ['session']);
    expect(training.calls, ['goal']);
    expect(reader.calls, [('goal', _latest)]);
    expect(cubit.state.published, _published);
  });

  test(
    'la semana pedida se normaliza y se conserva al refrescar y reintentar',
    () async {
      var fail = false;
      final cubit = AdaptivePlanCubit(
        goalId: 'goal',
        repository: _Training(_setup()),
        getDetail: _Detail((_, week, _) async {
          if (fail) throw StateError('offline');
          return _detail(week);
        }),
        publishedRepository: _Published(),
        initialWeek: _previous.add(const Duration(days: 2)),
      );
      addTearDown(cubit.close);
      fail = true;
      await cubit.load();
      expect(cubit.state.status, AdaptivePlanStatus.failure);
      fail = false;
      await cubit.load();
      expect(cubit.state.week, _previous);
      await cubit.load();
      expect(cubit.state.week, _previous);
    },
  );

  test('una semana lenta no sustituye la consulta más reciente', () async {
    final slow = Completer<PreparationDetail>();
    final cubit = AdaptivePlanCubit(
      goalId: 'goal',
      repository: _Training(_setup()),
      getDetail: _Detail(
        (_, week, _) =>
            week == _previous ? slow.future : Future.value(_detail(week)),
      ),
      publishedRepository: _Published(),
    );
    addTearDown(cubit.close);
    final pending = cubit.load(week: _previous);
    await Future<void>.delayed(Duration.zero);
    await cubit.load(week: _latest);
    slow.complete(_detail(_previous));
    await pending;
    expect(cubit.state.week, _latest);
    expect(cubit.state.detail!.weekStart, _latest);
  });

  test('cerrar por cambio de cuenta descarta la lectura tardía', () async {
    final slow = Completer<PreparationTrainingData>();
    final cubit = AdaptivePlanCubit(
      goalId: 'goal',
      repository: _Training(_setup(), pending: slow.future),
      getDetail: _Detail((_, week, _) async => _detail(week)),
      publishedRepository: _Published(),
    );
    final pending = cubit.load();
    await cubit.close();
    slow.complete(_setup());
    await pending;
    expect(cubit.isClosed, isTrue);
  });

  Future<({GoRouter router, AdaptivePlanCubit cubit})> mount(
    WidgetTester tester, {
    bool paused = false,
    bool failAccess = false,
    bool phases = false,
    double width = 390,
    double scale = 1,
    List<ScheduledWorkout> workouts = const [],
    PublishedAdaptiveWeek? published,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final cubit = AdaptivePlanCubit(
      goalId: 'goal',
      repository: _Training(
        _setup(status: paused ? 'paused' : 'training', phases: phases),
      ),
      getDetail: _Detail(
        (_, week, _) async => _detail(week, workouts: workouts),
      ),
      publishedRepository: _Published(published: published),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan/goal/goal/plan',
      routes: [
        GoRoute(
          path: '/plan/goal/goal/plan',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: AdaptivePlanPage(
              loadProAccess: failAccess
                  ? () async => throw StateError('offline')
                  : ProAccessFixture().load,
            ),
          ),
        ),
        for (final route in [
          '/plan/goal/goal/training',
          '/plan/goal/goal',
          '/plan/week/session/:id',
          '/assessment/history/workouts/:id',
        ])
          GoRoute(
            path: route,
            builder: (_, state) => Scaffold(body: Text('Destino ${state.uri}')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, cubit: cubit);
  }

  testWidgets(
    'Free pausado consulta la pauta retirada con su dosis, sin empezar',
    (tester) async {
      final result = await mount(tester, paused: true);
      expect(find.text('Fuerza anterior conservada'), findsOneWidget);
      await tester.tap(find.text('Fuerza anterior conservada'));
      await tester.pumpAndSettle();
      expect(find.text('Serie 1: 5 repeticiones'), findsOneWidget);
      expect(find.textContaining('Movilidad pautada'), findsOneWidget);
      expect(find.textContaining('Comenzar'), findsNothing);
      final resume = find.text('Retomar mi plan · Pro');
      await tester.ensureVisible(resume);
      await tester.pumpAndSettle();
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/goal/goal/training');
      result.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Fuerza anterior conservada'), findsOneWidget);
      await capturePerformanceWidget(tester, 'plan-adaptativo-pausado');
    },
  );

  testWidgets(
    'consultar una sesión abre su versión pautada y vuelve al mismo plan',
    (tester) async {
      final result = await mount(tester, workouts: [_workout()]);
      await tester.ensureVisible(find.text('Ver entrenamiento'));
      await tester.tap(find.text('Ver entrenamiento'));
      await tester.pumpAndSettle();
      expect(
        result.router.state.uri.toString(),
        '/plan/week/session/session?date=2026-11-02',
      );
      result.router.pop();
      await tester.pumpAndSettle();
      expect(result.cubit.state.week, _latest);
      expect(find.text('Mi plan adaptativo'), findsOneWidget);
    },
  );

  testWidgets('el resultado va al historial y no vuelve a empezar la sesión', (
    tester,
  ) async {
    final result = await mount(
      tester,
      workouts: [_workout(status: ScheduledWorkoutStatus.completed)],
    );
    await tester.ensureVisible(find.text('Ver resultado'));
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(
      result.router.state.uri.path,
      '/assessment/history/workouts/execution',
    );
  });

  testWidgets(
    'un fallo al consultar Pro no oculta la pauta ni sus resultados',
    (tester) async {
      await mount(tester, paused: true, failAccess: true);
      expect(find.text('Fuerza anterior conservada'), findsOneWidget);
      expect(find.text('Carrera anterior conservada'), findsOneWidget);
      expect(
        find.textContaining('No se ha podido comprobar tu acceso'),
        findsOneWidget,
      );
    },
  );

  testWidgets('la pauta no duplica la carrera incluida en ambos documentos', (
    tester,
  ) async {
    final running = <String, dynamic>{
      'name': 'Carrera publicada única',
      'minutes': 25,
      'date': '2026-11-02',
      'description': 'Pauta original.',
    };
    await mount(
      tester,
      paused: true,
      published: PublishedAdaptiveWeek(
        preparationDecision: {
          'sessions': [
            {...running, 'kind': 'running'},
          ],
        },
        runningDecision: {
          'sessions': [running],
        },
      ),
    );
    expect(find.text('Carrera publicada única'), findsOneWidget);
  });

  testWidgets(
    'la pauta de fuerza no recupera una carrera anterior de otro alcance',
    (tester) async {
      await mount(
        tester,
        paused: true,
        published: const PublishedAdaptiveWeek(
          preparationDecision: {
            'training_scope': 'performance',
            'sessions': [],
            'running': null,
          },
          runningDecision: {
            'sessions': [
              {
                'name': 'Carrera de una configuración anterior',
                'date': '2026-11-02',
                'minutes': 25,
              },
            ],
          },
        ),
      );
      expect(find.text('Carrera de una configuración anterior'), findsNothing);
      expect(
        find.text(
          'No hay entrenamientos adaptativos conservados en esta semana.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('conserva dos pautas de carrera con distinto tipo el mismo día', (
    tester,
  ) async {
    await mount(
      tester,
      paused: true,
      published: const PublishedAdaptiveWeek(
        runningDecision: {
          'sessions': [
            {
              'name': 'Trabajo publicado',
              'date': '2026-11-02',
              'minutes': 25,
              'kind': 'easy',
            },
            {
              'name': 'Trabajo publicado',
              'date': '2026-11-02',
              'minutes': 25,
              'kind': 'intervals',
            },
          ],
        },
      ),
    );
    expect(find.text('Trabajo publicado'), findsNWidgets(2));
  });

  testWidgets(
    'conserva unidades, límites e instrucciones de la dosis publicada',
    (tester) async {
      final modes = {
        'MAX_LOAD': 80,
        'HEIGHT': 0.4,
        'TIME_FOR_COURSE': 90,
        'REACTIVE_METRICS': 0.23,
        'REPS_IN_TIME': 12,
      };
      await mount(
        tester,
        paused: true,
        published: PublishedAdaptiveWeek(
          preparationDecision: {
            'sessions': [
              {
                'name': 'Dosis conservada',
                'date': '2026-11-02',
                'minutes': 40,
                'work': [
                  for (final entry in modes.entries)
                    {
                      'name': entry.key,
                      'dose': {
                        'targets': [entry.value],
                        'task': {
                          'measurement': entry.key,
                          if (entry.key == 'REPS_IN_TIME') ...{
                            'fixed_duration_seconds': 60,
                            'instructions':
                                'Usa el límite de la pauta original.',
                            'external_load_kg': 10,
                            'load_mode': 'assisted',
                          },
                          if (entry.key == 'TIME_FOR_COURSE')
                            'fixed_distance_meters': 100,
                        },
                      },
                    },
                ],
              },
            ],
          },
        ),
      );
      await tester.tap(find.text('Dosis conservada'));
      await tester.pumpAndSettle();
      for (final label in [
        'Serie 1: 80 kg',
        'Serie 1: 0.4 m',
        'Serie 1: 1:30 min',
        'Serie 1: 0.23 s de contacto medido',
        'Serie 1: 12 repeticiones',
        'Duración fijada: 1:00 min',
        'Distancia fijada: 100 m',
        'Asistencia: 10 kg',
        'Usa el límite de la pauta original.',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    },
  );

  testWidgets('consulta, semanas y fases caben a 320 px con texto 2×', (
    tester,
  ) async {
    await mount(tester, paused: true, phases: true, width: 320, scale: 2);
    await tester.ensureVisible(find.text('Fuerza anterior conservada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuerza anterior conservada'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retomar mi plan · Pro'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _Training implements PreparationTrainingRepository {
  _Training(this.setup, {this.pending});
  final PreparationTrainingData setup;
  final Future<PreparationTrainingData>? pending;
  final calls = <String>[];
  @override
  Future<PreparationTrainingData> load(String goalId) async {
    calls.add(goalId);
    return pending == null ? setup : await pending!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'La consulta no puede escribir: ${invocation.memberName}',
  );
}

class _Detail implements GetPreparationDetailUseCase {
  _Detail(this.read);
  final Future<PreparationDetail> Function(String, DateTime, DateTime) read;
  @override
  Future<PreparationDetail> call(String goalId, DateTime start, DateTime end) =>
      read(goalId, start, end);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Published implements PublishedAdaptiveWeekRepository {
  _Published({PublishedAdaptiveWeek? published})
    : published = published ?? _published;
  final PublishedAdaptiveWeek published;
  final calls = <(String, DateTime)>[];
  @override
  Future<PublishedAdaptiveWeek> read(String goalId, DateTime week) async {
    calls.add((goalId, week));
    return published;
  }
}
