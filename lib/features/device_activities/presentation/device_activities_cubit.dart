import 'package:device_activity_core/device_activity_core.dart';
import 'package:device_health/device_health.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../domain/running_history.dart';

enum DeviceActivitiesPhase { idle, loading, reading, saving, clearing }

final class RunningPreviewItem {
  const RunningPreviewItem(this.activity, this.previous);
  final ExternalActivity activity;
  final RunningHistoryItem? previous;
  bool get unchanged => previous?.activity.sameContentAs(activity) ?? false;
  bool get collision =>
      previous != null &&
      previous!.activity.revision == activity.revision &&
      !unchanged;
  String get id => activity.identity.externalId;
}

final class DeviceActivitiesState {
  DeviceActivitiesState({
    this.phase = DeviceActivitiesPhase.idle,
    this.connection,
    Iterable<RunningHistoryItem> history = const [],
    this.next,
    Iterable<RunningPreviewItem> preview = const [],
    Iterable<String> selected = const [],
    this.availability,
    this.historyProblem,
    this.readProblem,
    this.receipt,
    this.rejected = 0,
    this.truncated = false,
    this.pendingSave = false,
    this.pendingClear = false,
  }) : history = List.unmodifiable(history),
       preview = List.unmodifiable(preview),
       selected = Set.unmodifiable(selected);
  final DeviceActivitiesPhase phase;
  final RunningHistoryConnection? connection;
  final List<RunningHistoryItem> history;
  final RunningHistoryCursor? next;
  final List<RunningPreviewItem> preview;
  final Set<String> selected;
  final HealthStoreAvailability? availability;
  final RunningHistoryProblem? historyProblem;
  final HealthReadProblem? readProblem;
  final RunningSaveReceipt? receipt;
  final int rejected;
  final bool truncated, pendingSave, pendingClear;
  bool get busy => phase != DeviceActivitiesPhase.idle;
  DeviceActivitiesState copy({
    DeviceActivitiesPhase? phase,
    RunningHistoryConnection? connection,
    List<RunningHistoryItem>? history,
    RunningHistoryCursor? next,
    bool replaceNext = false,
    List<RunningPreviewItem>? preview,
    Set<String>? selected,
    HealthStoreAvailability? availability,
    RunningHistoryProblem? historyProblem,
    HealthReadProblem? readProblem,
    bool resetProblems = false,
    RunningSaveReceipt? receipt,
    int? rejected,
    bool? truncated,
    bool? pendingSave,
    bool? pendingClear,
  }) => DeviceActivitiesState(
    phase: phase ?? this.phase,
    connection: connection ?? this.connection,
    history: history ?? this.history,
    next: replaceNext ? next : (next ?? this.next),
    preview: preview ?? this.preview,
    selected: selected ?? this.selected,
    availability: availability ?? this.availability,
    historyProblem: resetProblems
        ? historyProblem
        : (historyProblem ?? this.historyProblem),
    readProblem: resetProblems
        ? readProblem
        : (readProblem ?? this.readProblem),
    receipt: receipt ?? this.receipt,
    rejected: rejected ?? this.rejected,
    truncated: truncated ?? this.truncated,
    pendingSave: pendingSave ?? this.pendingSave,
    pendingClear: pendingClear ?? this.pendingClear,
  );
}

final class DeviceActivitiesCubit extends Cubit<DeviceActivitiesState> {
  DeviceActivitiesCubit({
    required this.ownerId,
    required this.health,
    required this.history,
    DateTime Function()? nowUtc,
    String Function()? operationId,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _operationId = operationId ?? (() => const Uuid().v4()),
       super(DeviceActivitiesState()) {
    if (ownerId.trim().isEmpty || history.ownerId != ownerId) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
  }
  final String ownerId;
  final LocalRunningHealth health;
  final RunningHistoryRepository history;
  final DateTime Function() _nowUtc;
  final String Function() _operationId;
  int _generation = 0;
  bool _active = true, _foreground = true, _authorizing = false;
  RunningOperationFence? _fence;
  RunningSaveRequest? _pendingSave;
  ({RunningHistoryConnection connection, String operationId})? _pendingClear;

  bool _valid(int generation) =>
      !isClosed && _active && generation == _generation;
  int _begin() {
    _fence?.cancel();
    _fence = RunningOperationFence();
    return ++_generation;
  }

  Future<HealthStoreAvailability> _availability() async {
    try {
      return await health.availability();
    } catch (_) {
      return HealthStoreAvailability.unavailable;
    }
  }

  Future<void> initialize() async {
    if (!_active || state.busy) return;
    final generation = _begin();
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.loading,
        preview: [],
        selected: {},
        resetProblems: true,
      ),
    );
    final availability = _availability();
    try {
      final page = await history.load();
      final status = await availability;
      if (!_valid(generation)) return;
      emit(
        state.copy(
          phase: DeviceActivitiesPhase.idle,
          connection: page.connection,
          history: page.items,
          next: page.next,
          replaceNext: true,
          availability: status,
          resetProblems: true,
        ),
      );
    } catch (error) {
      final status = await availability;
      if (_valid(generation)) {
        _failHistory(error, availability: status);
      }
    }
  }

  Future<void> loadMore() async {
    if (!_active || state.busy || state.next == null) return;
    final generation = _begin();
    emit(state.copy(phase: DeviceActivitiesPhase.loading, resetProblems: true));
    try {
      final page = await history.load(before: state.next);
      if (!_valid(generation)) return;
      if (page.connection.generation != state.connection?.generation) {
        emit(state.copy(phase: DeviceActivitiesPhase.idle));
        await initialize();
        return;
      }
      final identities = state.history
          .map((item) => item.activity.identity)
          .toSet();
      if (page.items.any(
        (item) => identities.contains(item.activity.identity),
      )) {
        // Otro dispositivo pudo mover una revisión entre páginas. Reconsultar
        // descarta selecciones obsoletas sin inferir orden de revisiones opacas.
        emit(state.copy(phase: DeviceActivitiesPhase.idle));
        await initialize();
        return;
      }
      final items = {
        for (final item in state.history) item.id: item,
        for (final item in page.items) item.id: item,
      };
      emit(
        state.copy(
          phase: DeviceActivitiesPhase.idle,
          history: items.values.toList(),
          connection: page.connection,
          next: page.next,
          replaceNext: true,
        ),
      );
    } catch (error) {
      if (_valid(generation)) _failHistory(error);
    }
  }

  Future<void> read() async {
    if (!_active ||
        !_foreground ||
        state.busy ||
        _pendingSave != null ||
        _pendingClear != null) {
      return;
    }
    final generation = _begin();
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.reading,
        preview: [],
        selected: {},
        rejected: 0,
        truncated: false,
        resetProblems: true,
      ),
    );
    try {
      final available = await health.availability();
      if (!_valid(generation)) return;
      if (available != HealthStoreAvailability.available) {
        emit(
          state.copy(
            phase: DeviceActivitiesPhase.idle,
            availability: available,
          ),
        );
        return;
      }
      _authorizing = true;
      final consent = await health.requestReadAccess();
      _authorizing = false;
      if (!_valid(generation)) return;
      if (!_foreground) {
        emit(state.copy(phase: DeviceActivitiesPhase.idle));
        return;
      }
      if (consent == HealthReadConsent.denied) {
        throw const HealthReadException(HealthReadProblem.permissionRequired);
      }
      final end = _nowUtc();
      final result = await health.read(
        window: HealthReadWindow(
          startUtc: end.subtract(const Duration(days: 7)),
          endUtc: end,
        ),
        localSessionScope: _operationId(),
      );
      if (!_valid(generation)) return;
      final connection = state.connection;
      final preview = <RunningPreviewItem>[];
      for (final raw in result.activities) {
        if (raw.identity.ownerId != ownerId) {
          throw const RunningHistoryException(
            RunningHistoryProblem.accountChanged,
          );
        }
        final activity = connection == null
            ? raw
            : projectRunningActivity(raw, connection);
        final previous = state.history
            .where((h) => h.activity.identity == activity.identity)
            .firstOrNull;
        preview.add(RunningPreviewItem(activity, previous));
      }
      emit(
        state.copy(
          phase: DeviceActivitiesPhase.idle,
          preview: preview,
          selected: {
            for (final item in preview)
              if (item.previous == null) item.id,
          },
          rejected: result.rejectedRecords,
          truncated: result.truncated,
          availability: available,
        ),
      );
    } catch (error) {
      _authorizing = false;
      if (!_valid(generation)) return;
      if (error is RunningHistoryException) {
        _failHistory(error);
      } else {
        emit(
          state.copy(
            phase: DeviceActivitiesPhase.idle,
            preview: [],
            selected: {},
            readProblem: error is HealthReadException
                ? error.problem
                : HealthReadProblem.readFailed,
          ),
        );
      }
    }
  }

  void select(String id, bool selected) {
    if (!_active ||
        state.busy ||
        _pendingSave != null ||
        _pendingClear != null) {
      return;
    }
    final item = state.preview.where((p) => p.id == id).firstOrNull;
    if (item == null || item.unchanged || item.collision) return;
    final next = Set.of(state.selected);
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    emit(state.copy(selected: next));
  }

  Future<void> save() async {
    if (!_active || !_foreground || state.busy || _pendingClear != null) return;
    final connection = state.connection;
    if (connection == null) return;
    if (_pendingSave == null) {
      if (state.selected.isEmpty) return;
      _pendingSave = RunningSaveRequest(
        operationId: _operationId(),
        connection: connection,
        selections: [
          for (final item in state.preview)
            if (state.selected.contains(item.id))
              ReviewedRunningActivity(
                activity: item.activity,
                expectedSnapshotHash: item.previous?.snapshotHash,
              ),
        ],
      );
    }
    final generation = _begin();
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.saving,
        pendingSave: true,
        resetProblems: true,
      ),
    );
    try {
      final receipt = await history.save(_pendingSave!, _fence!);
      if (!_valid(generation)) return;
      _pendingSave = null;
      emit(
        state.copy(
          phase: DeviceActivitiesPhase.idle,
          preview: [],
          selected: {},
          pendingSave: false,
          receipt: receipt,
        ),
      );
      // El recibo no sustituye el head canónico: incluso un replay vuelve a consultar.
      await initialize();
    } catch (error) {
      if (!_valid(generation)) return;
      final problem = _historyProblem(error);
      if (problem != RunningHistoryProblem.unavailable) _pendingSave = null;
      _failHistory(error);
    }
  }

  Future<void> clearHistory() async {
    if (!_active || !_foreground || state.busy || state.connection == null) {
      return;
    }
    _pendingClear ??= (
      connection: state.connection!,
      operationId: _operationId(),
    );
    _pendingSave = null;
    final generation = _begin();
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.clearing,
        preview: [],
        selected: {},
        pendingSave: false,
        pendingClear: true,
        resetProblems: true,
      ),
    );
    try {
      await history.clear(
        connection: _pendingClear!.connection,
        operationId: _pendingClear!.operationId,
        fence: _fence!,
      );
      if (!_valid(generation)) return;
      _pendingClear = null;
      emit(DeviceActivitiesState(availability: state.availability));
      await initialize();
    } catch (error) {
      if (!_valid(generation)) return;
      if (_historyProblem(error) != RunningHistoryProblem.unavailable) {
        _pendingClear = null;
      }
      _failHistory(error);
    }
  }

  void suspend() {
    _foreground = false;
    if (_authorizing || !_active || isClosed) return;
    _begin();
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.idle,
        preview: [],
        selected: {},
        pendingSave: _pendingSave != null,
        pendingClear: _pendingClear != null,
      ),
    );
  }

  void resume() => _foreground = true;
  void deactivate() {
    _active = false;
    _generation++;
    _fence?.cancel();
    _pendingSave = null;
    _pendingClear = null;
    if (!isClosed) emit(DeviceActivitiesState());
  }

  RunningHistoryProblem _historyProblem(Object error) =>
      error is RunningHistoryException
      ? error.problem
      : RunningHistoryProblem.unavailable;
  void _failHistory(Object error, {HealthStoreAvailability? availability}) {
    final problem = _historyProblem(error);
    if (problem == RunningHistoryProblem.accountChanged) {
      deactivate();
      if (!isClosed) emit(DeviceActivitiesState(historyProblem: problem));
      return;
    }
    emit(
      state.copy(
        phase: DeviceActivitiesPhase.idle,
        historyProblem: problem,
        availability: availability,
        pendingSave: _pendingSave != null,
        pendingClear: _pendingClear != null,
      ),
    );
  }

  @override
  Future<void> close() {
    _active = false;
    _generation++;
    _fence?.cancel();
    _pendingSave = null;
    _pendingClear = null;
    return super.close();
  }
}
