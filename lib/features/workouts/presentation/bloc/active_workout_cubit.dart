import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
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
    required WorkoutTimerStore timerStore,
  }) : _getExecution = getExecution,
       _completeSet = completeSet,
       _skipSet = skipSet,
       _finishExecution = finishExecution,
       _abandonExecution = abandonExecution,
       _timerStore = timerStore,
       super(const ActiveWorkoutState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CompleteWorkoutSetUseCase _completeSet;
  final SkipWorkoutSetUseCase _skipSet;
  final FinishWorkoutExecutionUseCase _finishExecution;
  final AbandonWorkoutExecutionUseCase _abandonExecution;
  final WorkoutTimerStore _timerStore;
  Timer? _restTimer;

  Future<void> load() async {
    emit(const ActiveWorkoutState(status: ActiveWorkoutStatus.loading));
    try {
      final execution = await _getExecution(executionId);
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
      ),
    );
    try {
      await _completeSet(result);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      if (updated.currentSet == null || currentSet.restAfterSeconds == 0) {
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: updated,
          ),
        );
        return;
      }
      _startRest(updated, currentSet.restAfterSeconds);
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
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
      ),
    );
    try {
      await _skipSet(currentSet.id);
      await _timerStore.clear(_timerId(currentSet.id));
      final updated = await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.ready,
          execution: updated,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          errorMessage: 'No hemos podido saltar la serie.',
        ),
      );
    }
  }

  void _startRest(WorkoutExecution execution, int seconds) {
    _restTimer?.cancel();
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.resting,
        execution: execution,
        restSecondsRemaining: seconds,
      ),
    );
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.restSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.ready,
            execution: state.execution,
          ),
        );
      } else {
        emit(
          ActiveWorkoutState(
            status: ActiveWorkoutStatus.resting,
            execution: state.execution,
            restSecondsRemaining: remaining,
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
      ),
    );
    try {
      await _finishExecution(executionId, finalRpe: finalRpe, notes: notes);
      final updated = await _getExecution(executionId);
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.completed,
          execution: updated ?? execution,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
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
      ),
    );
    try {
      await _abandonExecution(executionId, reason);
      final currentSet = execution.currentSet;
      if (currentSet != null) {
        await _timerStore.clear(_timerId(currentSet.id));
      }
      final updated = await _getExecution(executionId);
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.abandoned,
          execution: updated ?? execution,
        ),
      );
    } catch (_) {
      emit(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.failure,
          execution: execution,
          errorMessage: 'No hemos podido abandonar la sesión.',
        ),
      );
    }
  }

  String _timerId(String resultId) => '$executionId:$resultId';

  @override
  Future<void> close() async {
    _restTimer?.cancel();
    await super.close();
  }
}
