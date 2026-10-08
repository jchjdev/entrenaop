import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

void main() {
  testWidgets('el descanso avisa a mitad, diez segundos y final', (
    tester,
  ) async {
    final repository = _Repository();
    final cues = _CueService();
    final cubit = _cubit(repository, cueService: cues);
    await cubit.load();
    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      restSecondsOverride: 40,
    );
    await tester.pump(const Duration(seconds: 20));
    expect(cues.cues, [WorkoutCue.halfway]);
    await tester.pump(const Duration(seconds: 10));
    expect(cues.cues, [WorkoutCue.halfway, WorkoutCue.tenSecondsRemaining]);
    await tester.pump(const Duration(seconds: 10));
    expect(cues.cues.last, WorkoutCue.restFinished);
    expect(cubit.state.status, ActiveWorkoutStatus.ready);
    await cubit.close();
  });

  testWidgets(
    'restaurar un descanso conserva la mitad original y no repite hitos',
    (tester) async {
      final repository = _Repository();
      final cues = _CueService();
      final store = _TimerStore(
        WorkoutTimerSnapshot(
          phase: WorkoutTimerPhase.running,
          targetSeconds: 40,
          preparationSeconds: 0,
          phaseStartedAt: DateTime.now().toUtc(),
          elapsedBeforeRun: const Duration(seconds: 25),
        ),
      );
      final cubit = _cubit(repository, timerStore: store, cueService: cues);
      await cubit.load();
      expect(store.snapshot!.targetSeconds, 40);
      expect(store.snapshot!.elapsedBeforeRun.inSeconds, 25);
      await tester.pump(const Duration(seconds: 5));
      expect(cues.cues, [WorkoutCue.tenSecondsRemaining]);
      cubit.skipRest();
      await tester.pump(const Duration(seconds: 10));
      expect(cues.cues, [WorkoutCue.tenSecondsRemaining]);
      await cubit.close();
    },
  );

  testWidgets('salir y retomar conserva series y no abandona la sesión', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      restSecondsOverride: 0,
    );
    final savedExecution = cubit.state.execution!;
    final registry = WorkflowExitRegistry();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: FilledButton(
              onPressed: () => context.push('/session'),
              child: const Text('Retomar'),
            ),
          ),
        ),
        GoRoute(
          path: '/session',
          onExit: (context, state) => registry.requestExit(state.pageKey),
          builder: (context, state) => WorkflowExitScope(
            controller: registry.controller(state.pageKey),
            child: BlocProvider.value(
              value: cubit,
              child: ActiveWorkoutPage(
                timerStore: _TimerStore(),
                cueService: _CueService(),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/session');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la sesión?'), findsOneWidget);
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/session');
    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir y retomar después'));
    await tester.pumpAndSettle();
    expect(cubit.state.execution, savedExecution);
    expect(repository.execution.status, WorkoutExecutionStatus.inProgress);
    await tester.tap(find.text('Retomar'));
    await tester.pumpAndSettle();
    expect(cubit.state.execution!.completedSetCount, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'omitir calentamiento pasa al trabajo sin resultados inventados',
    (tester) async {
      final repository = _Repository();
      repository.execution = repository.execution.copyWith(
        sets: const [
          WorkoutExecutionSet(
            id: 'warm-1',
            blockOrder: 0,
            blockName: 'Calentamiento',
            blockFormat: WorkoutBlockFormat.warmUp,
            itemOrder: 0,
            exerciseId: 'mobility',
            exerciseName: 'Movilidad',
            itemInstructions: 'Activación suave\nCamina con comodidad.',
            setOrder: 0,
            targetDurationSeconds: 180,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
          WorkoutExecutionSet(
            id: 'warm-2',
            blockOrder: 0,
            blockName: 'Calentamiento',
            blockFormat: WorkoutBlockFormat.warmUp,
            itemOrder: 1,
            exerciseId: 'mobility',
            exerciseName: 'Movilidad',
            setOrder: 0,
            targetDurationSeconds: 120,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
          WorkoutExecutionSet(
            id: 'work',
            blockOrder: 1,
            blockName: 'Trabajo',
            itemOrder: 0,
            exerciseId: 'push',
            exerciseName: 'Flexiones',
            setOrder: 0,
            targetReps: 8,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
        ],
      );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: ActiveWorkoutPage(
              timerStore: _TimerStore(),
              cueService: _CueService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Omitir calentamiento'));
      await tester.tap(find.text('Omitir calentamiento'));
      await tester.pumpAndSettle();
      expect(cubit.state.execution!.currentSet!.id, 'work');
      expect(
        cubit.state.execution!.sets
            .take(2)
            .every((s) => s.status == WorkoutSetStatus.skipped),
        isTrue,
      );
      expect(repository.lastSetResult, isNull);
      expect(find.text('Guardar serie'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  Future<(_Repository, ActiveWorkoutCubit)> mountEffortSet(
    WidgetTester tester,
  ) async {
    final repository = _Repository();
    repository.execution = repository.execution.copyWith(
      sets: const [
        WorkoutExecutionSet(
          id: 'effort-set',
          blockOrder: 0,
          blockName: 'Trabajo',
          itemOrder: 0,
          exerciseId: 'push-up',
          exerciseName: 'Flexiones',
          setOrder: 0,
          targetReps: 8,
          targetRir: 3,
          targetRpe: 7,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        ),
      ],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ActiveWorkoutPage(
            timerStore: _TimerStore(),
            cueService: _CueService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository, cubit);
  }

  testWidgets('guardar sin declarar esfuerzo conserva RIR y RPE ausentes', (
    tester,
  ) async {
    final (repository, _) = await mountEffortSet(tester);
    final save = find.text('Guardar serie');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.lastSetResult?.actualReps, 8);
    expect(repository.lastSetResult?.actualRir, isNull);
    expect(repository.lastSetResult?.actualRpe, isNull);
  });
  testWidgets(
    'RIR cero declarado llega al repositorio y no se sustituye por el objetivo',
    (tester) async {
      final (repository, _) = await mountEffortSet(tester);
      final field = find.widgetWithText(
        DropdownButtonFormField<double>,
        'RIR real',
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('0').last);
      await tester.pumpAndSettle();
      final save = find.text('Guardar serie');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.lastSetResult?.actualRir, 0);
      expect(repository.lastSetResult?.actualRpe, isNull);
    },
  );
  test('un EMOM descansa solo hasta el siguiente minuto', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      restSecondsOverride: 42,
    );

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, 42);
    expect(cubit.state.restCanBeSkipped, isFalse);
    expect(cubit.state.execution?.currentSet?.id, 'set-2');
  });

  test('omitir una estación EMOM conserva el minuto en curso', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.skipCurrentSet(restSecondsOverride: 31);

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, 31);
    expect(cubit.state.restCanBeSkipped, isFalse);
    expect(cubit.state.execution?.currentSet?.id, 'set-2');
  });

  test('restaura la espera hasta el siguiente minuto al volver', () async {
    final repository = _Repository();
    final timerStore = _TimerStore(
      WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.running,
        targetSeconds: 42,
        preparationSeconds: 0,
        phaseStartedAt: DateTime.now().toUtc().subtract(
          const Duration(seconds: 5),
        ),
        elapsedBeforeRun: Duration.zero,
        restCanBeSkipped: false,
      ),
    );
    final cubit = _cubit(repository, timerStore: timerStore);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, inInclusiveRange(36, 37));
    expect(cubit.state.restCanBeSkipped, isFalse);
  });

  test('guarda las vueltas y el parcial de un AMRAP', () async {
    final repository = _Repository()..execution = _amrapExecution();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.completeCurrentAmrap(
      const WorkoutAmrapResultInput(
        executionId: 'execution-1',
        blockOrder: 0,
        completedRounds: 4,
        partialItemOrder: 1,
        partialReps: 3,
      ),
    );

    expect(cubit.state.status, ActiveWorkoutStatus.ready);
    expect(cubit.state.execution?.currentSet, isNull);
    final result = cubit.state.execution?.amrapResults.single;
    expect(result?.completedRounds, 4);
    expect(result?.partialItemOrder, 1);
    expect(result?.partialReps, 3);
  });
}

ActiveWorkoutCubit _cubit(
  _Repository repository, {
  _TimerStore? timerStore,
  _CueService? cueService,
}) => ActiveWorkoutCubit(
  executionId: 'execution-1',
  getExecution: GetWorkoutExecutionUseCase(repository),
  completeSet: CompleteWorkoutSetUseCase(repository),
  completeAmrap: CompleteAmrapBlockUseCase(repository),
  skipSet: SkipWorkoutSetUseCase(repository),
  finishExecution: FinishWorkoutExecutionUseCase(repository),
  abandonExecution: AbandonWorkoutExecutionUseCase(repository),
  getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(repository),
  timerStore: timerStore ?? _TimerStore(),
  cueService: cueService ?? _CueService(),
);

class _Repository implements WorkoutRepository {
  WorkoutExecution execution = _execution();
  WorkoutSetResultInput? lastSetResult;

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async => execution;

  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async {
    lastSetResult = result;
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id == result.resultId
                ? set.copyWith(status: WorkoutSetStatus.completed)
                : set,
          )
          .toList(),
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<WorkoutMutationDisposition> completeAmrap(
    WorkoutAmrapResultInput result,
  ) async {
    final completedAt = DateTime.utc(2026, 9, 21, 20, 10);
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.blockOrder == result.blockOrder
                ? set.copyWith(
                    status: WorkoutSetStatus.completed,
                    completedAt: completedAt,
                  )
                : set,
          )
          .toList(),
      amrapResults: [
        WorkoutAmrapResult(
          blockOrder: result.blockOrder,
          completedRounds: result.completedRounds,
          partialItemOrder: result.partialItemOrder,
          partialReps: result.partialReps,
          completedAt: completedAt,
        ),
      ],
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<WorkoutMutationDisposition> skipSet(String resultId) async {
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id == resultId
                ? set.copyWith(status: WorkoutSetStatus.skipped)
                : set,
          )
          .toList(),
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<int> getPendingMutationCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkoutExecution _execution() => WorkoutExecution(
  id: 'execution-1',
  templateId: 'template-1',
  templateName: 'EMOM de fuerza',
  templateVersion: 1,
  status: WorkoutExecutionStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 21, 20),
  sets: const [
    WorkoutExecutionSet(
      id: 'set-1',
      blockOrder: 0,
      blockName: 'EMOM',
      blockFormat: WorkoutBlockFormat.emom,
      itemOrder: 0,
      exerciseId: 'exercise-1',
      exerciseName: 'Dominadas',
      setOrder: 0,
      targetReps: 8,
      restAfterSeconds: 60,
      status: WorkoutSetStatus.pending,
    ),
    WorkoutExecutionSet(
      id: 'set-2',
      blockOrder: 0,
      blockName: 'EMOM',
      blockFormat: WorkoutBlockFormat.emom,
      itemOrder: 0,
      exerciseId: 'exercise-1',
      exerciseName: 'Dominadas',
      setOrder: 1,
      targetReps: 8,
      restAfterSeconds: 60,
      status: WorkoutSetStatus.pending,
    ),
  ],
);

WorkoutExecution _amrapExecution() => WorkoutExecution(
  id: 'execution-1',
  templateId: 'template-1',
  templateName: 'AMRAP de fuerza',
  templateVersion: 1,
  status: WorkoutExecutionStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 21, 20),
  sets: const [
    WorkoutExecutionSet(
      id: 'set-1',
      blockOrder: 0,
      blockName: 'Trabajo principal',
      blockFormat: WorkoutBlockFormat.amrap,
      blockTimeCapSeconds: 600,
      itemOrder: 0,
      exerciseId: 'exercise-1',
      exerciseName: 'Dominadas',
      setOrder: 0,
      targetReps: 10,
      restAfterSeconds: 0,
      status: WorkoutSetStatus.pending,
    ),
    WorkoutExecutionSet(
      id: 'set-2',
      blockOrder: 0,
      blockName: 'Trabajo principal',
      blockFormat: WorkoutBlockFormat.amrap,
      blockTimeCapSeconds: 600,
      itemOrder: 1,
      exerciseId: 'exercise-2',
      exerciseName: 'Flexiones',
      setOrder: 0,
      targetReps: 8,
      restAfterSeconds: 0,
      status: WorkoutSetStatus.pending,
    ),
  ],
);

class _TimerStore implements WorkoutTimerStore {
  _TimerStore([this.snapshot]);

  WorkoutTimerSnapshot? snapshot;

  @override
  Future<void> clear(String timerId) async => snapshot = null;

  @override
  Future<WorkoutTimerSnapshot?> read(String timerId) async => snapshot;

  @override
  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _CueService implements WorkoutCueService {
  final cues = <WorkoutCue>[];

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> previewSound() async => true;
  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();

  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async {}

  @override
  Future<void> signal(WorkoutCue cue) async => cues.add(cue);
}
