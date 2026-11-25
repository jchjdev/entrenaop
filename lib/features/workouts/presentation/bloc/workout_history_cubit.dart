import '../../domain/usecases/record_workout_effort.dart';
import '../../domain/services/workout_session_draft_store.dart';
import '../../domain/services/workout_amrap_draft_store.dart';
import '../../domain/entities/pending_workout_mutation.dart';

import 'package:workout_core/workout_result_review.dart';

import '../../domain/usecases/workout_result_review_usecase.dart';

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
    GetWorkoutComparisonPage? getComparison,
    RecordWorkoutEffort? recordEffort,
    WorkoutSessionDraftStore? draftStore,
    WorkoutAmrapDraftStore? amrapDraftStore,
    CompleteWorkoutSetUseCase? completeSet,
    CompleteAmrapBlockUseCase? completeAmrap,
  }) : _recordEffort = recordEffort,
       _getComparison = getComparison,
       _getExecution = getExecution,
       _correctSet = correctSet,
       _completeSet = completeSet,
       _completeAmrap = completeAmrap,
       _draftStore = draftStore,
       _amrapDraftStore = amrapDraftStore,
       super(const WorkoutHistoryDetailState());

  final RecordWorkoutEffort? _recordEffort;
  bool get canRecordEffort =>
      _recordEffort != null &&
      state.execution?.status == WorkoutExecutionStatus.completed &&
      state.execution?.resultSource == WorkoutResultSource.device &&
      state.execution?.finalRpe == null;

  Future<void> recordEffort(int rpe) async {
    final execution = state.execution;
    if (!canRecordEffort ||
        execution == null ||
        state.isCorrecting ||
        isClosed) {
      return;
    }
    emit(
      WorkoutHistoryDetailState(
        status: WorkoutHistoryDetailStatus.loaded,
        execution: execution,
        isCorrecting: true,
      ),
    );
    try {
      await _recordEffort!(execution.id, rpe);
      if (isClosed) return;
      final updated = await _getExecution(executionId);
      if (isClosed) return;
      if (updated == null) throw StateError('No se encuentra la sesión.');
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: updated,
          correctionMessage: 'Esfuerzo registrado.',
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        WorkoutHistoryDetailState(
          status: WorkoutHistoryDetailStatus.loaded,
          execution: execution,
          correctionMessage: 'No se pudo añadir el esfuerzo. Actualiza la sesión y vuelve a intentarlo.',
        ),
      );
    }
  }

  final GetWorkoutComparisonPage? _getComparison;
  ReviewHistoryLoader? get comparisonLoader {
    final execution = state.execution, loader = _getComparison;
    if (execution == null || loader == null) return null;
    return (cursor) => loader(execution, cursor);
  }

  final String executionId;
  final GetWorkoutExecutionUseCase _getExecution;
  final CorrectWorkoutSetUseCase _correctSet;
  final CompleteWorkoutSetUseCase? _completeSet;
  final CompleteAmrapBlockUseCase? _completeAmrap;
  final WorkoutSessionDraftStore? _draftStore;
  final WorkoutAmrapDraftStore? _amrapDraftStore;
  Map<String, WorkoutSessionSetDraft> _drafts = {};
  Map<int, WorkoutAmrapDraft> _amrapDrafts = {};
  final _submitted = <String>{};
  final _submittedAmrap = <int>{};

  WorkoutSessionSetDraft? pendingDraft(String id) => _drafts[id];
  WorkoutAmrapDraft? pendingAmrapDraft(int order) => _amrapDrafts[order];

  bool canCompletePendingSet(WorkoutExecutionSet set) =>
      _completeSet != null &&
      !_submitted.contains(set.id) &&
      state.execution?.completedWithoutFullRecording == true &&
      (set.status == WorkoutSetStatus.pending &&
              _drafts[set.id]?.confirmed != true ||
          _drafts[set.id]?.hasUnconfirmedData == true &&
              set.canBeCorrectedAt(DateTime.now()));

  bool canCompletePendingAmrap(int order) =>
      _completeAmrap != null &&
      !_submittedAmrap.contains(order) &&
      state.execution?.completedWithoutFullRecording == true &&
      state.execution?.amrapResultFor(order) == null &&
      (state.execution?.sets.any(
            (set) =>
                set.blockOrder == order &&
                set.status == WorkoutSetStatus.pending,
          ) ??
          false);

  Future<void> updatePendingDraft(
    WorkoutSetResultInput result,
    Map<String, String> fields,
  ) async {
    if (isClosed || state.isCorrecting) return;
    final draft =
        _drafts[result.resultId] ?? WorkoutSessionSetDraft(result: result);
    _drafts[result.resultId] = draft.copyWith(
      result: result,
      fields: Map.of(fields),
    );
    try {
      await _draftStore?.write(executionId, Map.of(_drafts));
    } catch (_) {
      _partialState(
        message: 'No se pudo guardar el borrador en este dispositivo.',
      );
    }
  }

  Future<void> updatePendingAmrapDraft(
    int order,
    WorkoutAmrapDraft draft,
  ) async {
    if (isClosed || state.isCorrecting) return;
    _amrapDrafts[order] = draft;
    try {
      await _amrapDraftStore?.write(executionId, Map.of(_amrapDrafts));
    } catch (_) {
      _partialState(
        message: 'No se pudo guardar el borrador en este dispositivo.',
      );
    }
  }

  Future<bool> savePendingSet(
    WorkoutSetResultInput result,
    Map<String, String> fields,
  ) async {
    final set = state.execution?.sets
        .where((item) => item.id == result.resultId)
        .firstOrNull;
    if (isClosed ||
        state.isCorrecting ||
        set == null ||
        !canCompletePendingSet(set)) {
      return false;
    }
    if (!WorkoutSessionSetDraft(result: result).canConfirm(set)) {
      _partialState(
        message: 'Revisa los datos necesarios para confirmar la serie.',
      );
      return false;
    }
    return _savePartial(() async {
      var saved = WorkoutMutationDisposition.synced;
      if (set.status == WorkoutSetStatus.completed) {
        await _correctSet(
          WorkoutSetCorrectionInput(
            resultId: result.resultId,
            reason: 'Completar datos pendientes del entrenamiento',
            actualReps: result.actualReps,
            actualDurationSeconds: result.actualDurationSeconds,
            actualDistanceMeters: result.actualDistanceMeters,
            actualLoadKg: result.actualLoadKg,
            actualRpe: result.actualRpe,
            actualRir: result.actualRir,
            actualRecoveryDurationSeconds: result.actualRecoveryDurationSeconds,
            actualRecoveryDistanceMeters: result.actualRecoveryDistanceMeters,
            performanceResult: result.performanceResult,
          ),
        );
      } else {
        saved = await _completeSet!(result);
      }
      _submitted.add(set.id);
      if (saved == WorkoutMutationDisposition.queued) {
        _drafts[set.id] = WorkoutSessionSetDraft(
          result: result,
          fields: Map.of(fields),
          confirmed: true,
          saved: true,
        );
      } else {
        _drafts.remove(set.id);
      }
      await _draftStore
          ?.write(executionId, Map.of(_drafts))
          .catchError((Object _) {});
      return saved;
    });
  }

  Future<bool> savePendingAmrap(WorkoutAmrapResultInput result) async {
    if (isClosed ||
        state.isCorrecting ||
        result.executionId != executionId ||
        !canCompletePendingAmrap(result.blockOrder)) {
      return false;
    }
    return _savePartial(() async {
      final saved = await _completeAmrap!(result);
      _submittedAmrap.add(result.blockOrder);
      if (saved == WorkoutMutationDisposition.synced) {
        _amrapDrafts.remove(result.blockOrder);
        await _amrapDraftStore
            ?.write(executionId, Map.of(_amrapDrafts))
            .catchError((Object _) {});
      }
      return saved;
    });
  }

  Future<bool> _savePartial(
    Future<WorkoutMutationDisposition> Function() operation,
  ) async {
    _partialState(saving: true);
    try {
      final result = await operation();
      final updated = await _getExecution(executionId)
          .catchError((Object _) => null);
      _partialState(
        execution: updated,
        message: result == WorkoutMutationDisposition.queued
            ? 'Resultado pendiente de sincronizar.'
            : 'Resultado guardado.',
      );
      return true;
    } catch (_) {
      _partialState(
        message: 'No se pudo guardar el resultado. Puedes reintentar.',
      );
      return false;
    }
  }

  void _partialState({
    WorkoutExecution? execution,
    bool saving = false,
    String? message,
  }) {
    if (isClosed) return;
    emit(
      WorkoutHistoryDetailState(
        status: WorkoutHistoryDetailStatus.loaded,
        execution: execution ?? state.execution,
        isCorrecting: saving,
        correctionMessage: message,
      ),
    );
  }

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
      if (execution.completedWithoutFullRecording) {
        _drafts =
            await _draftStore
                ?.read(executionId)
                .catchError((Object _) => <String, WorkoutSessionSetDraft>{}) ??
            {};
        _amrapDrafts =
            await _amrapDraftStore
                ?.read(executionId)
                .catchError((Object _) => <int, WorkoutAmrapDraft>{}) ??
            {};
        if (isClosed || version != _detailLoadVersion) return;
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
