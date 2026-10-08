import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_intake_context_repository.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_week_plan_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/training_scope.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_context_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _troop = PreparationGoal(
  id: 'troop',
  program: PreparationProgram(
    id: PreparationProgramIds.armedForcesTroopEntry,
    name: 'Ingreso · Tropa',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
const _fas = PreparationGoal(
  id: 'fas',
  program: PreparationProgram(
    id: PreparationProgramIds.fasPeriodicAssessment,
    name: 'Evaluación periódica FAS',
    kind: PreparationProgramKind.internalAssessment,
  ),
);

void main() {
  setUp(() {
    final goals = _Goals();
    final schedule = _Schedule();
    sl.registerSingleton<PreparationGoalRepository>(goals);
    sl.registerSingleton<WorkoutScheduleRepository>(schedule);
    sl.registerSingleton<PreparationTrainingRepository>(_Training());
    sl.registerSingleton<RunningIntakeContextRepository>(_Context());
    sl.registerSingleton<RunningWeekPlanRepository>(_RunningWeek());
    sl.registerSingleton<TrainingPreferencesRepository>(_Preferences());
    sl.registerSingleton<TrainingContextRepository>(_SharedContext());
    sl.registerSingleton<ManageRunningReferenceSelectionUseCase>(_Selection());
    sl.registerFactory<PreparationGoalCubit>(
      () => PreparationGoalCubit(repository: goals)..load(),
    );
    sl.registerFactoryParam<PreparationDetailCubit, String, void>(
      (id, _) => PreparationDetailCubit(
        goalId: id,
        getDetail: GetPreparationDetailUseCase(
          goalRepository: goals,
          loadRunningTests: goals.loadRunningTests,
          loadTroopAssessments: (_) async => [],
          loadRunningReferenceCandidates: (_) async => [],
          scheduleRepository: schedule,
        ),
      )..load(),
    );
  });
  tearDown(() async => sl.reset());

  for (final suffix in [
    '',
    '/training',
    '/running-intake?dataOnly=true',
    '/running-context?program=true',
  ]) {
    testWidgets('cambiar Tropa por FAS renueva los datos en $suffix', (
      t,
    ) async {
      final router = AppRouter(_Auth());
      addTearDown(router.dispose);
      router.config.go('/plan/goal/troop$suffix');
      await t.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await t.pumpAndSettle();
      if (suffix == '/training') {
        expect(find.text('Paso 1 de 4 · Tu programa'), findsOneWidget);
      } else if (suffix.startsWith('/running-context')) {
        expect(
          (sl<RunningIntakeContextRepository>() as _Context)
              .requestedGoals
              .last,
          'troop',
        );
      } else {
        expect(find.text('Ingreso · Tropa'), findsOneWidget);
      }

      router.config.go('/plan/goal/fas$suffix');
      await t.pumpAndSettle();
      if (suffix == '/training') {
        expect(find.text('Paso 1 de 5 · Tu programa'), findsOneWidget);
        expect(find.text('Paso 1 de 4 · Tu programa'), findsNothing);
      } else if (suffix.startsWith('/running-context')) {
        expect(
          (sl<RunningIntakeContextRepository>() as _Context)
              .requestedGoals
              .last,
          'fas',
        );
      } else {
        expect(find.text('Evaluación periódica FAS'), findsOneWidget);
        expect(find.text('Ingreso · Tropa'), findsNothing);
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('carrera integrada sigue la preparación abierta', (t) async {
    final training = sl<PreparationTrainingRepository>() as _Training;
    training.runningForBoth = true;
    final router = AppRouter(_Auth());
    addTearDown(router.dispose);
    router.config.go('/plan/goal/troop/training');
    await t.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await t.pumpAndSettle();
    Future<void> openRunning() async {
      for (final label in [
        'Continuar con mi disponibilidad',
        'Continuar con carrera',
      ]) {
        await t.ensureVisible(find.text(label));
        await t.tap(find.text(label));
        await t.pumpAndSettle();
      }
    }

    await openRunning();
    expect(find.text('Ingreso · Tropa'), findsOneWidget);
    router.config.go('/plan/goal/fas/training');
    await t.pumpAndSettle();
    await openRunning();
    expect(find.text('Evaluación periódica FAS'), findsOneWidget);
    expect(find.text('Ingreso · Tropa'), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('una consulta tardía de Tropa no altera FAS; error: $fails', (
      t,
    ) async {
      final goals = sl<PreparationGoalRepository>() as _Goals;
      goals.delayedTroop = Completer<List<RunningTestResult>>();
      final router = AppRouter(_Auth());
      addTearDown(router.dispose);
      router.config.go('/plan/goal/troop');
      await t.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await t.pump();
      expect(goals.requestedTroopHistory, isTrue);
      router.config.go('/plan/goal/fas');
      await t.pumpAndSettle();
      expect(find.text('Evaluación periódica FAS'), findsOneWidget);
      if (fails) {
        goals.delayedTroop!.completeError(
          StateError('Consulta anterior fallida'),
        );
      } else {
        goals.delayedTroop!.complete([]);
      }
      await t.pumpAndSettle();
      expect(find.text('Evaluación periódica FAS'), findsOneWidget);
      expect(find.text('Ingreso · Tropa'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}

class _Auth implements AuthCubit {
  @override
  AuthState get state => AuthAuthenticated(
    user: UserEntity(
      id: 'test-user',
      email: 'identity@example.test',
      role: 'free',
      createdAt: DateTime(2026),
    ),
  );
  @override
  Stream<AuthState> get stream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Goals implements PreparationGoalRepository {
  Completer<List<RunningTestResult>>? delayedTroop;
  bool requestedTroopHistory = false;
  Future<List<RunningTestResult>> loadRunningTests(String id) async {
    if (id == 'troop' && delayedTroop != null) {
      requestedTroopHistory = true;
      return delayedTroop!.future;
    }
    return [];
  }

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [_troop, _fas];
  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => [
    _troop.program,
    _fas.program,
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Training implements PreparationTrainingRepository {
  @override
  Future<String?> getInProgressExecutionId() async => null;

  bool runningForBoth = false;
  @override
  Future<void> advance(String goalId) async {}
  @override
  Future<void> saveProgram(
    String goalId,
    DateTime targetDate,
    Map<String, dynamic> targets, {
    TrainingScope scope = TrainingScope.full,
  }) async {}
  @override
  Future<PreparationTrainingData> load(String goalId) async =>
      PreparationTrainingData(
        targetDate: DateTime.now().add(const Duration(days: 90)),
        hasRunning: runningForBoth || goalId == 'fas',
        catalog: [],
        context: const {
          'availability': {'1': 60, '3': 60, '5': 60},
          'capacity_confirmed': true,
        },
        runningContext: null,
        references: [],
        objectives: [],
        relations: [],
        publishedWeeks: [],
      );
  @override
  Future<void> saveContext(
    Map<String, int> availability,
    Set<String> equipment, {
    required bool reportsPain,
    required bool capacityConfirmed,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Context implements RunningIntakeContextRepository {
  final requestedGoals = <String>[];
  @override
  Future<RunningInitialContext?> get({
    required String goalId,
    required String programId,
  }) async {
    requestedGoals.add(goalId);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Selection implements ManageRunningReferenceSelectionUseCase {
  @override
  Future<RunningReferenceSelectionState> current(String goalId) async =>
      const RunningReferenceSelectionState(
        selection: null,
        candidate: null,
        issues: [],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RunningWeek implements RunningWeekPlanRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements TrainingPreferencesRepository {
  @override
  Future<TrainingPreferences?> get() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SharedContext implements TrainingContextRepository {
  @override
  Future<TrainingContextSettings> load() async => TrainingContextSettings(
    context: TrainingContext(
      availability: {'1': 60, '3': 60},
      equipment: {},
      reportsPain: false,
      capacityConfirmed: true,
    ),
    equipmentOptions: {},
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Schedule implements WorkoutScheduleRepository {
  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
