import '../models/workout_session_set_draft_model.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';

/// La cuenta queda fijada al crear el ejecutor; un cambio de cuenta no reasigna datos.
class SharedPreferencesWorkoutSessionDraftStore
    implements WorkoutSessionDraftStore {
  SharedPreferencesWorkoutSessionDraftStore(
    this.preferences, {
    required this.userId,
  });
  final SharedPreferences preferences;
  final String? userId;
  Future<void> _tail = Future.value();
  String _key(String executionId) {
    if (userId == null) {
      throw StateError('Se requiere una cuenta para guardar el borrador.');
    }
    return 'workout.session-draft.v1:$userId:$executionId';
  }

  @override
  Future<Map<String, WorkoutSessionSetDraft>> read(String executionId) async {
    await _tail;
    final encoded = preferences.getString(_key(executionId));
    if (encoded == null) return {};
    // Un borrador ilegible se conserva: no se sobrescribe como si estuviera vacío.
    final items = jsonDecode(encoded) as List;
    return {
      for (final item in items)
        (item as Map)['id'] as String: WorkoutSessionSetDraftModel.fromJson(
          Map<String, dynamic>.from(item),
        ),
    };
  }

  @override
  Future<void> write(
    String executionId,
    Map<String, WorkoutSessionSetDraft> drafts,
  ) {
    final encoded = jsonEncode(
      drafts.values.map((d) => WorkoutSessionSetDraftModel.toJson(d)).toList(),
    );
    final key = _key(executionId);
    final next = _tail.then((_) async {
      if (!await preferences.setString(key, encoded)) {
        throw StateError('No se ha guardado el borrador.');
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  Future<void> clear(String executionId) {
    final key = _key(executionId);
    final next = _tail.then((_) async {
      await preferences.remove(key);
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
