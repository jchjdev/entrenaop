import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';

class WorkoutHistoryCubit extends Cubit<WorkoutHistoryState> {
  WorkoutHistoryCubit({required GetWorkoutHistoryUseCase getHistory})
    : _getHistory = getHistory,
      super(const WorkoutHistoryState());

  final GetWorkoutHistoryUseCase _getHistory;
  int _loadVersion = 0;
  static const pageSize = 30;

  Future<void> filter(WorkoutHistoryQuery query) async {
    if (isClosed || query == state.query) return;
    _loadVersion++;
    emit(WorkoutHistoryState(query: query));
    await load();
  }

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_loadVersion;
    final previous = state.executions;
    final query = state.query;
    final previousHasMore = state.hasMore;
    final count = previous.length > pageSize ? previous.length : pageSize;
    emit(
      WorkoutHistoryState(
        status: previous.isEmpty
            ? WorkoutHistoryStatus.loading
            : WorkoutHistoryStatus.loaded,
        executions: previous,
        isRefreshing: previous.isNotEmpty,
        query: query,
        hasMore: previousHasMore,
      ),
    );
    try {
      final executions = <WorkoutExecution>[];
      WorkoutHistoryCursor? cursor;
      var hasMore = false;
      // Reconsultar por páginas evita truncar al límite máximo del servidor
      // cuando el usuario ya ha abierto un historial largo.
      while (executions.length < count) {
        final remaining = count - executions.length;
        final amount = remaining < pageSize ? remaining : pageSize;
        final rows = await _getHistory(
          query: query.page(limit: amount + 1, before: cursor),
        );
        if (isClosed || version != _loadVersion) return;
        executions.addAll(rows.take(amount));
        hasMore = rows.length > amount;
        if (!hasMore) break;
        final last = executions.last;
        cursor = WorkoutHistoryCursor(startedAt: last.startedAt, id: last.id);
      }
      emit(
        WorkoutHistoryState(
          status: WorkoutHistoryStatus.loaded,
          executions: executions,
          query: query,
          hasMore: hasMore,
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
          query: query,
          hasMore: previousHasMore,
          errorMessage: previous.isEmpty
              ? 'No hemos podido cargar tus sesiones.'
              : 'No hemos podido actualizar. Sigues viendo la última consulta; puedes reintentar.',
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (isClosed ||
        !state.hasMore ||
        state.isRefreshing ||
        state.isLoadingMore ||
        state.executions.isEmpty) {
      return;
    }
    final version = _loadVersion;
    final previous = state.executions;
    final last = previous.last;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final rows = await _getHistory(
        query: state.query.page(
          limit: pageSize + 1,
          before: WorkoutHistoryCursor(startedAt: last.startedAt, id: last.id),
        ),
      );
      if (isClosed || version != _loadVersion) return;
      final seen = previous.map((e) => e.id).toSet();
      emit(
        state.copyWith(
          executions: [
            ...previous,
            ...rows.take(pageSize).where((e) => seen.add(e.id)),
          ],
          isLoadingMore: false,
          hasMore: rows.length > pageSize,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        state.copyWith(
          isLoadingMore: false,
          moreError: 'No se pudieron cargar más sesiones. Puedes reintentar.',
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
  int _detailLoadVersion = 0;

  Future<void> load() async {
    if (isClosed) return;
    final version = ++_detailLoadVersion;
    emit(
      const WorkoutHistoryDetailState(
        status: WorkoutHistoryDetailStatus.loading,
      ),
    );
    try {
      final execution = await _getExecution(executionId);
      if (isClosed || version != _detailLoadVersion) return;
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
      if (isClosed || version != _detailLoadVersion) return;
      emit(
        const WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.failure,
          errorMessage: 'No hemos podido abrir esta sesión.',
        ),
      );
    }
  }

  Future<void> correct(WorkoutSetCorrectionInput correction) async {
    if (isClosed) return;
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
      if (isClosed) return;
      final updated = await _getExecution(executionId);
      if (isClosed) return;
      if (updated == null) throw StateError('Execution disappeared');
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: updated,
          correctionMessage: 'Serie corregida y cambio registrado.',
        ),
      );
    } catch (_) {
      if (isClosed) return;
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
