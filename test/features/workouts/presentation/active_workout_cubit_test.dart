import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

ActiveWorkoutCubit _cubit(_Repository repository, {_TimerStore? timerStore}) =>
    ActiveWorkoutCubit(
      executionId: 'execution-1',
      getExecution: GetWorkoutExecutionUseCase(repository),
      completeSet: CompleteWorkoutSetUseCase(repository),
      completeAmrap: CompleteAmrapBlockUseCase(repository),
      skipSet: SkipWorkoutSetUseCase(repository),
      finishExecution: FinishWorkoutExecutionUseCase(repository),
      abandonExecution: AbandonWorkoutExecutionUseCase(repository),
      getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(
        repository,
      ),
      timerStore: timerStore ?? _TimerStore(),
      cueService: _CueService(),
    );

class _Repository implements WorkoutRepository {
  WorkoutExecution execution = _execution();

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async => execution;

  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async {
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
  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();

  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async {}

  @override
  Future<void> signal(WorkoutCue cue) async {}
}
