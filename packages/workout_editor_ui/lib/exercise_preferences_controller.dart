import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';

/// Estado de una única instancia de editor y un único puerto de cuenta/contexto.
/// No almacena catálogo, medios ni credenciales y no comparte caché global.
class ExercisePreferencesController extends ChangeNotifier {
  ExercisePreferencesController(this.source);
  final ExerciseCatalogPreferences source;

  final _entries = <String, ExercisePreferenceEntry>{};
  final _pending = <_Action>[];
  Future<void>? _reading;
  bool _disposed = false, _draining = false;
  bool loaded = false;
  int recentLimit = 20;
  String? error;
  bool get loading => _reading != null;
  bool get canRetry => error != null;

  bool favorite(String id) => _entries[id]?.favorite ?? false;
  bool pending(String id) => _pending.any((a) => a.exerciseId == id);
  DateTime? selectedAt(String id) => _entries[id]?.lastSelectedAt;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() {
    if (_disposed) return Future.value();
    if (_reading case final current?) return current;
    if (_draining) return Future.value();
    // Diferir el cuerpo permite registrar la tarea antes de notificar a la UI.
    final task = Future<void>.microtask(_load);
    _reading = task;
    _notify();
    return task;
  }

  Future<void> _load() async {
    try {
      final snapshot = await source.read();
      if (_disposed) return;
      _replace(snapshot);
      if (_pending.isEmpty) error = null;
    } catch (_) {
      if (!_disposed) error = 'No se pudieron cargar favoritos y recientes.';
    } finally {
      _reading = null;
      _notify();
    }
  }

  void _replace(ExercisePreferenceSnapshot snapshot) {
    final revisions = _entries.values.where((e) => !e.favorite).toList();
    _entries
      ..clear()
      // Las desmarcadas pueden salir del snapshot limitado a favoritos/recientes.
      // Conservar su revisión evita volver a escribir con revisión cero.
      ..addEntries(
        revisions.map(
          (e) => MapEntry(
            e.exerciseId,
            ExercisePreferenceEntry(
              exerciseId: e.exerciseId,
              favorite: false,
              favoriteRevision: e.favoriteRevision,
            ),
          ),
        ),
      )
      ..addEntries(snapshot.entries.map((e) => MapEntry(e.exerciseId, e)));
    loaded = true;
    recentLimit = snapshot.recentLimit;
  }

  void toggleFavorite(String id) {
    if (_disposed || !loaded || loading || pending(id)) return;
    try {
      _enqueue(
        _Action.favorite(
          id,
          source.newOperationId(),
          !favorite(id),
          _entries[id]?.favoriteRevision ?? 0,
        ),
      );
    } catch (_) {
      error = 'No se pudo iniciar el cambio. Revisa tu acceso.';
      _notify();
    }
  }

  /// Solo el editor llama a este método al aceptar la selección, no la búsqueda.
  void recordSelection(String id) {
    if (_disposed) return;
    try {
      _enqueue(_Action.selection(id, source.newOperationId()));
    } catch (_) {
      error = 'No se pudo registrar el reciente. Revisa tu acceso.';
      _notify();
    }
  }

  void _enqueue(_Action action) {
    if (_pending.isEmpty) error = null;
    _pending.add(action);
    _notify();
    // Un fallo retiene UUID/payload del mismo ejercicio, sin bloquear los demás.
    unawaited(_drain());
  }

  void retry() {
    if (_disposed || _draining || loading) return;
    error = null;
    if (_pending.isEmpty) {
      unawaited(load());
    } else {
      for (final action in _pending) {
        action.failed = false;
      }
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      await _reading;
      if (_disposed) return;
      while (true) {
        final action = _nextAction();
        if (action == null) break;
        try {
          if (action.favorite case final favorite?) {
            final entry = await source.setFavorite(
              action.exerciseId,
              favorite,
              expectedRevision: action.revision!,
              operationId: action.operationId,
            );
            if (_disposed) return;
            _merge(entry);
          } else {
            final entry = await source.recordSelection(
              action.exerciseId,
              operationId: action.operationId,
            );
            if (_disposed) return;
            // La fecha canónica procede del servidor, también en los reintentos.
            _merge(entry);
          }
          _pending.remove(action);
          if (!_pending.any((a) => a.failed)) error = null;
        } on ExercisePreferenceConflict catch (conflict) {
          if (_disposed) return;
          _merge(conflict.current);
          _pending.remove(action);
          error =
              'El favorito cambió en otra pestaña. Revisa su estado actual.';
          _notify();
        } catch (_) {
          if (_disposed) return;
          error = 'No se pudo guardar la preferencia. Puedes reintentar.';
          action.failed = true;
        }
        _notify();
      }
    } finally {
      _draining = false;
      _notify();
    }
  }

  _Action? _nextAction() {
    final blocked = <String>{};
    for (final action in _pending) {
      if (action.failed) {
        blocked.add(action.exerciseId);
      } else if (!blocked.contains(action.exerciseId)) {
        return action;
      }
    }
    return null;
  }

  void _merge(ExercisePreferenceEntry entry) {
    final previous = _entries[entry.exerciseId];
    final favorite =
        previous != null && previous.favoriteRevision > entry.favoriteRevision
        ? previous
        : entry;
    final oldDate = previous?.lastSelectedAt;
    final newDate = entry.lastSelectedAt;
    _entries[entry.exerciseId] = ExercisePreferenceEntry(
      exerciseId: entry.exerciseId,
      favorite: favorite.favorite,
      favoriteRevision: favorite.favoriteRevision,
      lastSelectedAt:
          oldDate != null && (newDate == null || oldDate.isAfter(newDate))
          ? oldDate
          : newDate,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.clear();
    _entries.clear();
    super.dispose();
  }
}

class _Action {
  _Action.favorite(
    this.exerciseId,
    this.operationId,
    this.favorite,
    this.revision,
  );
  _Action.selection(this.exerciseId, this.operationId)
    : favorite = null,
      revision = null;

  final String exerciseId, operationId;
  final bool? favorite;
  final int? revision;
  bool failed = false;
}
