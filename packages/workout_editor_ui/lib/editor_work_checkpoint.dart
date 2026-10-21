import 'dart:convert';

import 'package:flutter/foundation.dart';

String canonicalEditorState(Map<String, dynamic> state) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList(growable: false);
    return value;
  }

  return jsonEncode(canonical(state));
}

/// Una petición incierta se confirma antes de enviar el siguiente estado.
class EditorWorkCheckpoint<W> extends ChangeNotifier {
  EditorWorkCheckpoint({
    required this.work,
    required Map<String, dynamic> state,
    required this.save,
    required this.isNew,
    required this.isConflict,
    required this.conflictError,
  }) : _latest = canonicalEditorState(state),
       _saved = canonicalEditorState(state);

  W work;
  final Future<W> Function(W, Map<String, dynamic>) save;
  final bool Function(W) isNew;
  final bool Function(Object) isConflict;
  final Object Function() conflictError;
  String _latest;
  String? _saved, _request;
  Future<void>? _saving;
  bool conflict = false;
  Object? error;
  bool _disposed = false;
  bool get saving => _saving != null;
  bool get dirty => _latest != _saved || _request != null;
  void update(Map<String, dynamic> state) {
    _latest = canonicalEditorState(state);
  }

  /// Solo acepta una respuesta confirmada de una operación explícita del servidor.
  void accept(W confirmed, Map<String, dynamic> state) {
    work = confirmed;
    _latest = _saved = canonicalEditorState(state);
    _request = null;
    error = null;
    conflict = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> flush() async {
    if (_saving != null) return _saving;
    if (conflict) throw conflictError();
    if (isNew(work)) _request ??= _latest;
    final future = _flush();
    _saving = future;
    _notify();
    try {
      await future;
    } finally {
      _saving = null;
      _notify();
    }
  }

  Future<void> _flush() async {
    error = null;
    try {
      while (dirty) {
        _request ??= _latest;
        final sent = _request!;
        work = await save(work, jsonDecode(sent) as Map<String, dynamic>);
        _saved = sent;
        _request = null;
      }
    } catch (e) {
      error = e;
      conflict = isConflict(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
