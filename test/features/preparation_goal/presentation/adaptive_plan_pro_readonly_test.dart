import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/published_adaptive_week_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/adaptive_plan_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/adaptive_plan_page.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';
import 'package:entrenaop/features/training_plan/presentation/widgets/training_preparation_overview.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pro_access_fixture.dart';

final _week = DateTime(2026, 11, 2);
const _goal = PreparationGoal(
  id: 'goal',
  program: PreparationProgram(
    id: 'fas',
    name: 'Mi preparación conservada',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
const _generationMessage =
    'La siguiente semana se preparará al resolver las sesiones.';

ScheduledWorkout _workout(String id, ScheduledWorkoutStatus status) =>
    ScheduledWorkout(
      id: id,
      templateId: 'template-$id',
      templateName: 'Sesión $id',
      templateVersion: 4,
      scheduledDate: _week,
      source: ScheduledWorkoutSource.algorithm,
      status: status,
      preparationGoalId: 'goal',
      executionId: status == ScheduledWorkoutStatus.planned
          ? null
          : 'execution-$id',
    );

PreparationTrainingData _setup({
  required bool proRequired,
  String status = 'training',
}) => PreparationTrainingData(
  proRequired: proRequired,
  catalog: const [],
  context: null,
  runningContext: null,
  references: const [],
  objectives: const [],
  relations: const [],
  publishedWeeks: status == 'draft' ? const [] : [_week],
  programName: _goal.program.name,
  programState: {
    'status': status,
    'auto_advance': true,
    'message': _generationMessage,
  },
);

void main() {
  Future<({GoRouter router, _ReadOnlyTraining repository})> mount(
    WidgetTester tester, {
    bool proRequired = true,
    String status = 'training',
    List<ScheduledWorkout>? workouts,
    LoadProAccess? loadAccess,
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _ReadOnlyTraining(
      _setup(proRequired: proRequired, status: status),
    );
    final cubit = AdaptivePlanCubit(
      goalId: 'goal',
      repository: repository,
      getDetail: _Detail(
        workouts ?? [_workout('pendiente', ScheduledWorkoutStatus.planned)],
      ),
      publishedRepository: _Published(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan/goal/goal/plan',
      routes: [
        GoRoute(
          path: '/plan/goal/:id/plan',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: AdaptivePlanPage(
              loadProAccess: loadAccess ?? ProAccessFixture().load,
            ),
          ),
        ),
        GoRoute(
          path: '/plan/week/session/:id',
          builder: (_, _) =>
              const Scaffold(body: Text('Vista previa conservada')),
        ),
        GoRoute(
          path: '/assessment/history/workouts/:id',
          builder: (_, _) => const Scaffold(body: Text('Resultado conservado')),
        ),
        GoRoute(
          path: '/plan/goal/:id/training',
          builder: (_, _) => const Scaffold(body: Text('Acceso Pro existente')),
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
    return (router: router, repository: repository);
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Free consulta pautas conservadas sin prometer generación ni escribir',
    (tester) async {
      final result = await mount(tester);
      expect(find.text('Tu plan guardado'), findsOneWidget);
      expect(find.text(_generationMessage), findsNothing);
      expect(find.text('TU PLAN ADAPTATIVO'), findsNothing);
      await show(tester, find.text('Ver entrenamiento'));
      expect(find.text('02/11/2026 · Entrenamiento del plan'), findsOneWidget);
      await tester.tap(find.text('Ver entrenamiento'));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/week/session/pendiente');
      expect(result.repository.forbiddenCalls, isEmpty);
      result.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Tu plan guardado'), findsOneWidget);
    },
  );

  testWidgets(
    'perder Pro mantiene el resultado y la consulta de una sesión ya abierta',
    (tester) async {
      final result = await mount(
        tester,
        workouts: [
          _workout('resultado', ScheduledWorkoutStatus.completed),
          _workout('abierta', ScheduledWorkoutStatus.inProgress),
        ],
      );
      await show(tester, find.text('Ver resultado'));
      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      expect(
        result.router.state.uri.path,
        '/assessment/history/workouts/execution-resultado',
      );
      result.router.pop();
      await tester.pumpAndSettle();
      await show(tester, find.text('Sesión abierta'));
      final openCard = find.ancestor(
        of: find.text('Sesión abierta'),
        matching: find.byType(EntrenaCard),
      );
      final preview = find.descendant(
        of: openCard,
        matching: find.text('Ver entrenamiento'),
      );
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/week/session/abierta');
      expect(result.repository.forbiddenCalls, isEmpty);
    },
  );

  testWidgets('Free sin plan iniciado ofrece configurar, no retomar', (
    tester,
  ) async {
    await mount(tester, status: 'draft', workouts: const []);
    await show(tester, find.text('Configurar mi plan · Pro'));
    expect(find.text('Retomar mi plan · Pro'), findsNothing);
    expect(find.text('Configurar mi plan · Pro').hitTestable(), findsOneWidget);
  });

  testWidgets('una pausa voluntaria Pro conserva su motivo independiente', (
    tester,
  ) async {
    await mount(
      tester,
      proRequired: false,
      status: 'paused',
      loadAccess: ProAccessFixture(isPro: true).load,
    );
    expect(find.text('PLAN ADAPTATIVO · PAUSADO'), findsOneWidget);
    expect(find.text('Tu plan guardado'), findsNothing);
    expect(
      find.textContaining('retomarlo requiere revisar la propuesta'),
      findsOneWidget,
    );
  });

  testWidgets(
    'el fallo de comprobación comercial no oculta consulta ni resultados',
    (tester) async {
      final result = await mount(
        tester,
        loadAccess: () async => throw StateError('Sin red'),
      );
      await show(
        tester,
        find.text('No se ha podido comprobar tu acceso. Vuelve a intentarlo.'),
      );
      expect(find.text('Sesión pendiente'), findsOneWidget);
      expect(find.text('Tu plan guardado'), findsOneWidget);
      expect(result.repository.forbiddenCalls, isEmpty);
    },
  );

  testWidgets('la consulta Free y sus acciones caben a 320 px con texto 2×', (
    tester,
  ) async {
    await mount(tester, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);
    await show(tester, find.text('Retomar mi plan · Pro'));
    expect(tester.takeException(), isNull);
    expect(find.text('Retomar mi plan · Pro').hitTestable(), findsOneWidget);
  });

  for (final hasOpenSession in [false, true]) {
    testWidgets(
      'portada Free mantiene consulta y sesión abierta: $hasOpenSession',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/plan',
          routes: [
            GoRoute(
              path: '/plan',
              builder: (_, _) => Scaffold(
                body: ListView(
                  children: [
                    TrainingPreparationOverview(
                      loadProAccess: ProAccessFixture().load,
                      overview: PreparationOverview(
                        assessments: const [],
                        preferences: null,
                        goals: const [_goal],
                        weekStart: _week,
                        weeklyWorkouts: [
                          if (hasOpenSession)
                            _workout(
                              'abierta',
                              ScheduledWorkoutStatus.inProgress,
                            ),
                        ],
                        programs: const [
                          AdaptiveProgramProgress(
                            goalId: 'goal',
                            name: 'Mi preparación conservada',
                            status: 'paused',
                            message: _generationMessage,
                            proRequired: true,
                          ),
                        ],
                      ),
                    ),
                  ],
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
        expect(find.text('Consultar mi plan'), findsOneWidget);
        expect(find.text(_generationMessage), findsNothing);
        expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
        if (hasOpenSession) {
          await show(tester, find.text('ENTRENAMIENTO EN CURSO'));
          expect(
            find.text(
              'Puedes continuar y terminar este entrenamiento ya iniciado.',
            ),
            findsOneWidget,
          );
        } else {
          expect(find.text('PRÓXIMO ENTRENAMIENTO'), findsNothing);
        }
      },
    );
  }
}

class _ReadOnlyTraining implements PreparationTrainingRepository {
  _ReadOnlyTraining(this.data);
  final PreparationTrainingData data;
  final forbiddenCalls = <Symbol>[];
  @override
  Future<PreparationTrainingData> load(String goalId) async => data;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    forbiddenCalls.add(invocation.memberName);
    throw StateError('La consulta no modifica ni comienza el entrenamiento.');
  }
}

class _Detail implements GetPreparationDetailUseCase {
  _Detail(this.workouts);
  final List<ScheduledWorkout> workouts;
  @override
  Future<PreparationDetail> call(
    String goalId,
    DateTime start,
    DateTime end,
  ) async => PreparationDetail(
    goal: _goal,
    weekStart: start,
    weekEnd: end,
    weeklyWorkouts: workouts,
  );
}

class _Published implements PublishedAdaptiveWeekRepository {
  @override
  Future<PublishedAdaptiveWeek> read(String goalId, DateTime week) async =>
      const PublishedAdaptiveWeek();
}
