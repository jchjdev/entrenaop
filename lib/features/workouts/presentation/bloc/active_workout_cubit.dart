import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';

class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  ActiveWorkoutCubit({
    required this.executionId,
    required GetWorkoutExecutionUseCase getExecution,
    required CompleteWorkoutSetUseCase completeSet,
    required CompleteAmrapBlockUseCase completeAmrap,
    required SkipWorkoutSetUseCase skipSet,
    required FinishWorkoutExecutionUseCase finishExecution,
    required AbandonWorkoutExecutionUseCase abandonExecution,
    required GetPendingWorkoutMutationCountUseCase getPendingMutationCount,
    required WorkoutTimerStore timerStore,
    required WorkoutCueService cueService,
  }) : _getExecution = getExecution,
       _completeSet = completeSet,
       _completeAmrap = completeAmrap,
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
  final CompleteAmrapBlockUseCase _completeAmrap;
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
      final restSnapshot = await _timerStore.read(_restTimerId);
      if (execution.status == WorkoutExecutionStatus.inProgress &&
          execution.currentSet != null &&
          restSnapshot?.phase == WorkoutTimerPhase.running) {
        final elapsedSinceWrite = DateTime.now().toUtc().difference(
          restSnapshot!.phaseStartedAt,
        );
        final elapsed =
            restSnapshot.elapsedBeforeRun +
            (elapsedSinceWrite.isNegative ? Duration.zero : elapsedSinceWrite);
        final remaining = restSnapshot.targetSeconds - elapsed.inSeconds;
        if (remaining > 0) {
          _startRest(
            execution,
            remaining,
            pendingSyncCount,
            canBeSkipped: restSnapshot.restCanBeSkipped,
          );
          return;
        }
      }
      if (restSnapshot != null) await _timerStore.clear(_restTimerId);
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

  Future<void> completeCurrentSet(
    WorkoutSetResultInput result, {
    int? restSecondsOverride,
  }) async {
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
      final restSeconds = (restSecondsOverride ?? currentSet.restAfterSeconds)
          .clamp(0, 3600)
          .toInt();
      if (updated.currentSet == null || restSeconds == 0) {
        await _timerStore.clear(_restTimerId);
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: updated,
            pendingSyncCount: pendingSyncCount,
          ),
        );
        return;
      }
      _startRest(
        updated,
        restSeconds,
        pendingSyncCount,
        canBeSkipped: currentSet.blockFormat != WorkoutBlockFormat.emom,
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido guardar la serie.',
        ),
      );
      await _timerStore.clear(_restTimerId);
    }
  }

  Future<void> completeCurrentAmrap(WorkoutAmrapResultInput result) async {
    final execution = state.execution;
    final currentSet = execution?.currentSet;
    if (execution == null ||
        currentSet == null ||
        currentSet.blockFormat != WorkoutBlockFormat.amrap ||
        currentSet.blockOrder != result.blockOrder) {
      return;
    }
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
        pendingSyncCount: state.pendingSyncCount,
      ),
    );
    try {
      final disposition = await _completeAmrap(result);
      await _timerStore.clear(_amrapTimerId(result.blockOrder));
      final updated = disposition == WorkoutMutationDisposition.queued
          ? _completeAmrapLocally(execution, result)
          : await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.ready,
          execution: updated,
          pendingSyncCount: await _getPendingMutationCount(),
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          pendingSyncCount: state.pendingSyncCount,
          errorMessage: 'No hemos podido guardar el resultado AMRAP.',
        ),
      );
    }
  }

  Future<void> skipCurrentSet({int? restSecondsOverride}) async {
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
      final restSeconds = (restSecondsOverride ?? 0).clamp(0, 3600).toInt();
      if (updated.currentSet != null && restSeconds > 0) {
        _startRest(
          updated,
          restSeconds,
          pendingSyncCount,
          canBeSkipped: currentSet.blockFormat != WorkoutBlockFormat.emom,
        );
        return;
      }
      await _timerStore.clear(_restTimerId);
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
    int pendingSyncCount, {
    bool canBeSkipped = true,
  }) {
    _restTimer?.cancel();
    unawaited(
      _timerStore.write(
        _restTimerId,
        WorkoutTimerSnapshot(
          phase: WorkoutTimerPhase.running,
          targetSeconds: seconds,
          preparationSeconds: 0,
          phaseStartedAt: DateTime.now().toUtc(),
          elapsedBeforeRun: Duration.zero,
          restCanBeSkipped: canBeSkipped,
        ),
      ),
    );
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.resting,
        execution: execution,
        restSecondsRemaining: seconds,
        restCanBeSkipped: canBeSkipped,
        pendingSyncCount: pendingSyncCount,
      ),
    );
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.restSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_timerStore.clear(_restTimerId));
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
            restCanBeSkipped: state.restCanBeSkipped,
            pendingSyncCount: state.pendingSyncCount,
          ),
        );
      }
    });
  }

  void skipRest() {
    if (state.status != ActiveWorkoutStatus.resting ||
        !state.restCanBeSkipped) {
      return;
    }
    _restTimer?.cancel();
    unawaited(_timerStore.clear(_restTimerId));
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
      await _timerStore.clear(_restTimerId);
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

  String get _restTimerId => '$executionId:rest';

  String _amrapTimerId(int blockOrder) => '$executionId:amrap:$blockOrder';

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

  WorkoutExecution _completeAmrapLocally(
    WorkoutExecution execution,
    WorkoutAmrapResultInput result,
  ) => execution.copyWith(
    sets: execution.sets
        .map(
          (set) => set.blockOrder == result.blockOrder
              ? set.copyWith(
                  status: WorkoutSetStatus.completed,
                  completedAt: DateTime.now().toUtc(),
                )
              : set,
        )
        .toList(growable: false),
    amrapResults: [
      ...execution.amrapResults,
      WorkoutAmrapResult(
        blockOrder: result.blockOrder,
        completedRounds: result.completedRounds,
        partialItemOrder: result.partialItemOrder,
        partialReps: result.partialReps,
        completedAt: DateTime.now().toUtc(),
      ),
    ],
  );

  @override
  Future<void> close() async {
    _restTimer?.cancel();
    await super.close();
  }
}
