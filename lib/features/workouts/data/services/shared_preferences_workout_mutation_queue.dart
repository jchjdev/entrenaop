import 'dart:convert';

import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_mutation_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutMutationQueue implements WorkoutMutationQueue {
  SharedPreferencesWorkoutMutationQueue(this._preferences);

  static const _key = 'workout.pending_mutations.v1';
  final SharedPreferences _preferences;

  @override
  Future<List<PendingWorkoutMutation>> readAll() async {
    final encoded = _preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      final rows = (jsonDecode(encoded) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      final mutations = rows.map(_fromJson).toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return mutations;
    } on FormatException {
      await _preferences.remove(_key);
      return const [];
    } on TypeError {
      await _preferences.remove(_key);
      return const [];
    }
  }

  @override
  Future<void> enqueue(PendingWorkoutMutation mutation) async {
    final current = await readAll();
    if (current.any((item) => item.operationId == mutation.operationId)) return;
    await _write([...current, mutation]);
  }

  @override
  Future<void> remove(String operationId) async {
    final current = await readAll();
    await _write(
      current
          .where((mutation) => mutation.operationId != operationId)
          .toList(growable: false),
    );
  }

  Future<void> _write(List<PendingWorkoutMutation> mutations) async {
    if (mutations.isEmpty) {
      await _preferences.remove(_key);
      return;
    }
    await _preferences.setString(
      _key,
      jsonEncode(mutations.map(_toJson).toList(growable: false)),
    );
  }

  Map<String, dynamic> _toJson(PendingWorkoutMutation mutation) => {
    'operation_id': mutation.operationId,
    'type': mutation.type.name,
    'resource_id': mutation.resourceId,
    'values': mutation.values,
    'created_at': mutation.createdAt.toUtc().toIso8601String(),
  };

  PendingWorkoutMutation _fromJson(Map<String, dynamic> json) =>
      PendingWorkoutMutation(
        operationId: json['operation_id'] as String,
        type: WorkoutMutationType.values.byName(json['type'] as String),
        resourceId: json['resource_id'] as String,
        values: Map<String, dynamic>.from(json['values'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
