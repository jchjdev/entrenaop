import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';

class WorkoutHistoryCubit extends Cubit<WorkoutHistoryState> {
  WorkoutHistoryCubit({required GetWorkoutHistoryUseCase getHistory})
    : _getHistory = getHistory,
      super(const WorkoutHistoryState());

  final GetWorkoutHistoryUseCase _getHistory;

  Future<void> load() async {
    emit(const WorkoutHistoryState(status: WorkoutHistoryStatus.loading));
    try {
      final executions = await _getHistory();
      emit(
        WorkoutHistoryState(
          status: WorkoutHistoryStatus.loaded,
          executions: executions,
        ),
      );
    } catch (_) {
      emit(
        const WorkoutHistoryState(
          status: WorkoutHistoryStatus.failure,
          errorMessage: 'No hemos podido cargar tus sesiones.',
        ),
      );
    }
  }
}

class WorkoutHistoryDetailCubit extends Cubit<WorkoutHistoryDetailState> {
  WorkoutHistoryDetailCubit({
    required this.executionId,
    required GetWorkoutExecutionUseCase getExecution,
  }) : _getExecution = getExecution,
       super(const WorkoutHistoryDetailState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;

  Future<void> load() async {
    emit(
      const WorkoutHistoryDetailState(
        status: WorkoutHistoryDetailStatus.loading,
      ),
    );
    try {
      final execution = await _getExecution(executionId);
      if (execution == null ||
          execution.status == WorkoutExecutionStatus.inProgress) {
        emit(
          const WorkoutHistoryDetailState(
            status: WorkoutHistoryDetailStatus.failure,
            errorMessage: 'No encontramos esta sesión en tu historial.',
          ),
        );
        return;
      }
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: execution,
        ),
      );
    } catch (_) {
      emit(
        const WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.failure,
          errorMessage: 'No hemos podido abrir esta sesión.',
        ),
      );
    }
  }
}
