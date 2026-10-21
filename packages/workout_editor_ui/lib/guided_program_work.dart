import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:workout_core/guided_program.dart';

String newGuidedWorkId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class GuidedWork {
  const GuidedWork({
    required this.id,
    required this.state,
    this.revision = 0,
    this.baseProgramId,
    this.finalizedProgramId,
    this.updatedAt,
    this.discarded = false,
    this.permanentlyDeleted = false,
  });
  final String id;
  final Map<String, dynamic> state;
  final int revision;
  final String? baseProgramId, finalizedProgramId;
  final DateTime? updatedAt;
  final bool discarded, permanentlyDeleted;
  String get name => (state['name'] as String?)?.trim().isNotEmpty == true
      ? state['name'] as String
      : 'Programa sin nombre';
}

class GuidedWorkConflict implements Exception {
  const GuidedWorkConflict();
}

// JSONB puede devolver otro orden de claves. Solo se ordenan mapas: las listas
// conservan el orden de sesiones y los textos crudos conservan la edición.
Object? _canonicalWorkValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonicalWorkValue(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalWorkValue).toList(growable: false);
  }
  return value;
}

String _encodeWorkState(Map<String, dynamic> state) =>
    jsonEncode(_canonicalWorkValue(state));

abstract interface class GuidedWorkRepository {
  Future<List<GuidedWork>> list();
  Future<GuidedWork?> load(String id);
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state);
  Future<String> finalize(GuidedWork work, GuidedProgram program);
  Future<void> discard(GuidedWork work);
}

/// Serializa escrituras y conserva la petición incierta antes de enviar cambios nuevos.
class GuidedWorkController extends ChangeNotifier {
  GuidedWorkController(this.repository, this.work, Map<String, dynamic> state)
    : _latest = _encodeWorkState(state),
      _saved = _encodeWorkState(state);
  final GuidedWorkRepository repository;
  GuidedWork work;
  String _latest;
  String? _saved, _request;
  Future<void>? _saving;
  bool conflict = false;
  Object? error;
  bool get saving => _saving != null;
  bool get dirty => _latest != _saved || _request != null;
  bool _disposed = false;
  void update(Map<String, dynamic> state) {
    _latest = _encodeWorkState(state);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> flush() async {
    if (_saving != null) return _saving;
    if (conflict) throw const GuidedWorkConflict();
    if (work.revision == 0) _request ??= _latest;
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
        work = await repository.save(
          work,
          jsonDecode(sent) as Map<String, dynamic>,
        );
        _saved = sent;
        _request = null;
      }
    } catch (e) {
      error = e;
      conflict = e is GuidedWorkConflict;
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
