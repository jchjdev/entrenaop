import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';

class WorkoutHistoryCubit extends Cubit<WorkoutHistoryState> {
  WorkoutHistoryCubit({required GetWorkoutHistoryUseCase getHistory})
    : _getHistory = getHistory,
      super(const WorkoutHistoryState());

  final GetWorkoutHistoryUseCase _getHistory;
  int _loadVersion = 0;

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    final previous = state.executions;
    emit(
      WorkoutHistoryState(
        status: previous.isEmpty
            ? WorkoutHistoryStatus.loading
            : WorkoutHistoryStatus.loaded,
        executions: previous,
        isRefreshing: previous.isNotEmpty,
      ),
    );
    try {
      final executions = await _getHistory();
      if (isClosed || version != _loadVersion) return;
      emit(
        WorkoutHistoryState(
          status: WorkoutHistoryStatus.loaded,
          executions: executions,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        WorkoutHistoryState(
          status: previous.isEmpty
              ? WorkoutHistoryStatus.failure
              : WorkoutHistoryStatus.loaded,
          executions: previous,
          errorMessage: previous.isEmpty
              ? 'No hemos podido cargar tus sesiones.'
              : 'No hemos podido actualizar. Sigues viendo la última consulta; puedes reintentar.',
        ),
      );
    }
  }
}

class WorkoutHistoryDetailCubit extends Cubit<WorkoutHistoryDetailState> {
  WorkoutHistoryDetailCubit({
    required this.executionId,
    required GetWorkoutExecutionUseCase getExecution,
    required CorrectWorkoutSetUseCase correctSet,
  }) : _getExecution = getExecution,
       _correctSet = correctSet,
       super(const WorkoutHistoryDetailState());

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CorrectWorkoutSetUseCase _correctSet;

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

  Future<void> correct(WorkoutSetCorrectionInput correction) async {
    final execution = state.execution;
    if (execution == null || state.isCorrecting) return;
    emit(
      WorkoutHistoryDetailState(
        status: WorkoutHistoryDetailStatus.loaded,
        execution: execution,
        isCorrecting: true,
      ),
    );
    try {
      await _correctSet(correction);
      final updated = await _getExecution(executionId);
      if (updated == null) throw StateError('Execution disappeared');
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: updated,
          correctionMessage: 'Serie corregida y cambio registrado.',
        ),
      );
    } catch (_) {
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: execution,
          correctionMessage: 'No hemos podido corregirla. El plazo o el límite pueden haber finalizado.',
        ),
      );
    }
  }
}
