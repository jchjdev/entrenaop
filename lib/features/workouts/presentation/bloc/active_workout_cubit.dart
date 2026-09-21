import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';

class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  ActiveWorkoutCubit({
    required this.executionId,
    required GetWorkoutExecutionUseCase getExecution,
    required CompleteWorkoutSetUseCase completeSet,
    required SkipWorkoutSetUseCase skipSet,
    required FinishWorkoutExecutionUseCase finishExecution,
    required AbandonWorkoutExecutionUseCase abandonExecution,
    required GetPendingWorkoutMutationCountUseCase getPendingMutationCount,
    required WorkoutTimerStore timerStore,
    required WorkoutCueService cueService,
  }) : _getExecution = getExecution,
       _completeSet = completeSet,
       _skipSet = skipSet,
       _finishExecution = finishExecution,
       _abandonExecution = abandonExecution,
       _getPendingMutationCount = getPendingMutationCount,
       _timerStore = timerStore,
       _cueService = cueService,
       super(const ActiveWorkoutState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CompleteWorkoutSetUseCase _completeSet;
  final SkipWorkoutSetUseCase _skipSet;
  final FinishWorkoutExecutionUseCase _finishExecution;
  final AbandonWorkoutExecutionUseCase _abandonExecution;
  final GetPendingWorkoutMutationCountUseCase _getPendingMutationCount;
  final WorkoutTimerStore _timerStore;
  final WorkoutCueService _cueService;
  Timer? _restTimer;

  Future<void> load() async {
    emit(const ActiveWorkoutState(status: ActiveWorkoutStatus.loading));
    try {
      final execution = await _getExecution(executionId);
      final pendingSyncCount = await _getPendingMutationCount();
      if (execution == null) {
        emit(
          const ActiveWorkoutState(
            status: ActiveWorkoutStatus.failure,
            errorMessage: 'No encontramos esta ejecución.',
          ),
        );
        return;
      }
      emit(
        ActiveWorkoutState(
          status: switch (execution.status) {
            WorkoutExecutionStatus.completed => ActiveWorkoutStatus.completed,
            WorkoutExecutionStatus.abandoned => ActiveWorkoutStatus.abandoned,
            WorkoutExecutionStatus.inProgress => ActiveWorkoutStatus.ready,
          },
          execution: execution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      emit(
        const ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          errorMessage: 'No hemos podido recuperar la sesión.',
        ),
      );
    }
  }

  Future<void> completeCurrentSet(WorkoutSetResultInput result) async {
    final execution = state.execution;
    final currentSet = execution?.currentSet;
    if (execution == null || currentSet == null) return;

    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _completeSet(result);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = disposition == WorkoutMutationDisposition.queued
          ? _completeLocally(execution, currentSet.id, result)
          : await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      final pendingSyncCount = await _getPendingMutationCount();
      if (updated.currentSet == null || currentSet.restAfterSeconds == 0) {
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: updated,
            pendingSyncCount: pendingSyncCount,
          ),
        );
        return;
      }
      _startRest(updated, currentSet.restAfterSeconds, pendingSyncCount);
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido guardar la serie.',
        ),
      );
    }
  }

  Future<void> skipCurrentSet() async {
    final execution = state.execution;
    final currentSet = execution?.currentSet;
    if (execution == null || currentSet == null) return;

    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _skipSet(currentSet.id);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = disposition == WorkoutMutationDisposition.queued
          ? _skipLocally(execution, currentSet.id)
          : await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      final pendingSyncCount = await _getPendingMutationCount();
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.ready,
          execution: updated,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido saltar la serie.',
        ),
      );
    }
  }

  void _startRest(
    WorkoutExecution execution,
    int seconds,
    int pendingSyncCount,
  ) {
    _restTimer?.cancel();
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.resting,
        execution: execution,
        restSecondsRemaining: seconds,
        pendingSyncCount: pendingSyncCount,
      ),
    );
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.restSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_cueService.signal(WorkoutCue.restFinished));
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: state.execution,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      } else {
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.resting,
            execution: state.execution,
            restSecondsRemaining: remaining,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      }
    });
  }

  void skipRest() {
    if (state.status != ActiveWorkoutStatus.resting) return;
    _restTimer?.cancel();
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.ready,
        execution: state.execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
  }

  Future<void> finish({required int finalRpe, String? notes}) async {
    final execution = state.execution;
    if (execution == null || execution.currentSet != null) return;
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _finishExecution(
        executionId,
        finalRpe: finalRpe,
        notes: notes,
      );
      final updated = disposition == WorkoutMutationDisposition.queued
          ? execution.copyWith(
              status: WorkoutExecutionStatus.completed,
              completedAt: DateTime.now().toUtc(),
              finalRpe: finalRpe,
              notes: notes?.trim(),
            )
          : await _getExecution(executionId);
      final pendingSyncCount = await _getPendingMutationCount();
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.completed,
          execution: updated ?? execution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido finalizar la sesión.',
        ),
      );
    }
  }

  Future<void> abandon(WorkoutAbandonmentReason reason) async {
    final execution = state.execution;
    if (execution == null ||
        execution.status != WorkoutExecutionStatus.inProgress) {
      return;
    }
    _restTimer?.cancel();
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _abandonExecution(executionId, reason);
      final currentSet = execution.currentSet;
      if (currentSet != null) {
        await _timerStore.clear(_timerId(currentSet.id));
      }
      final updated = disposition == WorkoutMutationDisposition.queued
          ? execution.copyWith(
              status: WorkoutExecutionStatus.abandoned,
              completedAt: DateTime.now().toUtc(),
              abandonmentReason: reason,
            )
          : await _getExecution(executionId);
      final pendingSyncCount = await _getPendingMutationCount();
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.abandoned,
          execution: updated ?? execution,
          pendingSyncCount: pendingSyncCount,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido abandonar la sesión.',
        ),
      );
    }
  }

  String _timerId(String resultId) => '$executionId:$resultId';

  WorkoutExecution _completeLocally(
    WorkoutExecution execution,
    String resultId,
    WorkoutSetResultInput result,
  ) => execution.copyWith(
    sets: execution.sets
        .map(
          (set) => set.id == resultId
              ? set.copyWith(
                  status: WorkoutSetStatus.completed,
                  actualReps: result.actualReps,
                  actualDurationSeconds: result.actualDurationSeconds,
                  actualDistanceMeters: result.actualDistanceMeters,
                  actualLoadKg: result.actualLoadKg,
                  actualRpe: result.actualRpe,
                  actualRir: result.actualRir,
                  completedAt: DateTime.now().toUtc(),
                )
              : set,
        )
        .toList(growable: false),
  );

  WorkoutExecution _skipLocally(WorkoutExecution execution, String resultId) =>
      execution.copyWith(
        sets: execution.sets
            .map(
              (set) => set.id == resultId
                  ? set.copyWith(status: WorkoutSetStatus.skipped)
                  : set,
            )
            .toList(growable: false),
      );

  @override
  Future<void> close() async {
    _restTimer?.cancel();
    await super.close();
  }
}
