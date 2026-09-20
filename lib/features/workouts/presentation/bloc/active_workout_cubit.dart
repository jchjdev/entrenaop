import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';

class ActiveWorkoutCubit extends Cubit<ActiveWorkoutState> {
  ActiveWorkoutCubit({
    required this.executionId,
    required GetWorkoutExecutionUseCase getExecution,
    required CompleteWorkoutSetUseCase completeSet,
    required SkipWorkoutSetUseCase skipSet,
    required FinishWorkoutExecutionUseCase finishExecution,
  }) : _getExecution = getExecution,
       _completeSet = completeSet,
       _skipSet = skipSet,
       _finishExecution = finishExecution,
       super(const ActiveWorkoutState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CompleteWorkoutSetUseCase _completeSet;
  final SkipWorkoutSetUseCase _skipSet;
  final FinishWorkoutExecutionUseCase _finishExecution;
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
          status: execution.status == WorkoutExecutionStatus.completed
              ? ActiveWorkoutStatus.completed
              : ActiveWorkoutStatus.ready,
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

  Future<void> finish(int finalRpe) async {
    final execution = state.execution;
    if (execution == null || execution.currentSet != null) return;
    emit(
      ActiveWorkoutState(
        status: ActiveWorkoutStatus.saving,
        execution: execution,
      ),
    );
    try {
      await _finishExecution(executionId, finalRpe);
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

  @override
  Future<void> close() async {
    _restTimer?.cancel();
    await super.close();
  }
}
