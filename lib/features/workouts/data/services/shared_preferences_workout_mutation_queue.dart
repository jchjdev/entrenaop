import 'dart:convert';

import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_mutation_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutMutationQueue implements WorkoutMutationQueue {
  SharedPreferencesWorkoutMutationQueue(
    this._preferences, {
    required this.currentUserId,
    this.ownsLegacyMutation,
  });

  static const _legacyKey = 'workout.pending_mutations.v1';
  static const _prefix = 'workout.pending_mutations.v2:';
  final SharedPreferences _preferences;
  final String? Function() currentUserId;
  final Future<bool> Function(PendingWorkoutMutation mutation, String userId)?
  ownsLegacyMutation;
  Future<void> _tail = Future.value();

  // Serializa lectura y escritura para no perder series registradas a la vez.
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  Future<List<PendingWorkoutMutation>> readAll() {
    final userId = currentUserId();
    if (userId == null) return Future.value(const []);
    return _serial(() async {
      final current = _read(userId);
      await _migrateLegacy(userId, current);
      // Una consulta antigua no debe entregar datos de A tras entrar B.
      if (currentUserId() != userId) return const [];
      return current..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  @override
  Future<void> enqueue(PendingWorkoutMutation mutation) => _serial(() async {
    final current = _read(mutation.userId);
    if (current.any((item) => item.operationId == mutation.operationId)) return;
    await _write(mutation.userId, [...current, mutation]);
  });

  @override
  Future<void> remove(String operationId, {required String userId}) =>
      _serial(() async {
        await _write(
          userId,
          _read(userId)
              .where((mutation) => mutation.operationId != operationId)
              .toList(),
        );
      });

  List<PendingWorkoutMutation> _read(String userId) {
    final encoded = _preferences.getString('$_prefix$userId');
    if (encoded == null) return [];
    final mutations = _decode(encoded, userId);
    if (mutations.any((item) => item.userId != userId)) {
      throw const FormatException('La cola contiene otra cuenta.');
    }
    // Un contenido ilegible se conserva y no se sobrescribe con una cola vacía.
    return mutations;
  }

  Future<void> _migrateLegacy(
    String userId,
    List<PendingWorkoutMutation> current,
  ) async {
    final verifier = ownsLegacyMutation;
    final encoded = _preferences.getString(_legacyKey);
    if (verifier == null || encoded == null) return;
    final List<PendingWorkoutMutation> legacy;
    try {
      legacy = _decode(encoded, userId, legacy: true);
    } on Object {
      return;
    }
    final markerKey = '$_prefix$userId:migrated-v1';
    final migrated = (_preferences.getStringList(markerKey) ?? []).toSet();
    for (final mutation in legacy) {
      if (mutation.userId != userId) continue;
      if (migrated.contains(mutation.operationId)) continue;
      if (currentUserId() != userId) return;
      final bool owned;
      try {
        owned = await verifier(mutation, userId);
      } on Object {
        // Sin conexión se reintenta después, conservando el original intacto.
        continue;
      }
      if (currentUserId() != userId) return;
      if (!owned) continue;
      if (!current.any((item) => item.operationId == mutation.operationId)) {
        current.add(mutation);
      }
      // Primero persistir; el marcador evita resucitar una operación enviada.
      await _write(userId, current);
      migrated.add(mutation.operationId);
      await _preferences.setStringList(markerKey, migrated.toList());
    }
    // v1 se conserva como copia recuperable: no tenía propietario registrado.
  }

  Future<void> _write(
    String userId,
    List<PendingWorkoutMutation> mutations,
  ) async {
    final key = '$_prefix$userId';
    final saved = mutations.isEmpty
        ? await _preferences.remove(key)
        : await _preferences.setString(
            key,
            jsonEncode(mutations.map(_toJson).toList(growable: false)),
          );
    if (!saved) throw StateError('No se ha podido guardar la cola local.');
  }

  Map<String, dynamic> _toJson(PendingWorkoutMutation mutation) => {
    'user_id': mutation.userId,
    'operation_id': mutation.operationId,
    'type': mutation.type.name,
    'resource_id': mutation.resourceId,
    'values': mutation.values,
    'created_at': mutation.createdAt.toUtc().toIso8601String(),
  };

  List<PendingWorkoutMutation> _decode(
    String encoded,
    String userId, {
    bool legacy = false,
  }) => (jsonDecode(encoded) as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .map(
        (json) => PendingWorkoutMutation(
          userId: legacy ? userId : json['user_id'] as String,
          operationId: json['operation_id'] as String,
          type: WorkoutMutationType.values.byName(json['type'] as String),
          resourceId: json['resource_id'] as String,
          values: Map<String, dynamic>.from(json['values'] as Map),
          createdAt: DateTime.parse(json['created_at'] as String),
        ),
      )
      .toList();
}
