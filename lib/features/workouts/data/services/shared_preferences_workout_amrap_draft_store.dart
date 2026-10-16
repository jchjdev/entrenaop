import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/workout_amrap_draft_store.dart';
import '../models/workout_amrap_draft_model.dart';

class SharedPreferencesWorkoutAmrapDraftStore
    implements WorkoutAmrapDraftStore {
  SharedPreferencesWorkoutAmrapDraftStore(
    this.preferences, {
    required this.userId,
  });

  final SharedPreferences preferences;
  final String? userId;
  Future<void> _tail = Future.value();

  String _key(String executionId) {
    if (userId == null) throw StateError('Se requiere una cuenta.');
    return 'workout.amrap-draft.v1:$userId:$executionId';
  }

  @override
  Future<Map<int, WorkoutAmrapDraft>> read(String executionId) async {
    await _tail;
    final raw = preferences.getString(_key(executionId));
    if (raw == null) return {};
    // Un contenido ilegible no se sustituye por una cuenta vacía.
    final items = jsonDecode(raw) as Map<String, dynamic>;
    return items.map(
      (key, value) => MapEntry(
        int.parse(key),
        WorkoutAmrapDraftModel.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      ),
    );
  }

  @override
  Future<void> write(String executionId, Map<int, WorkoutAmrapDraft> drafts) {
    final raw = jsonEncode(
      drafts.map(
        (key, draft) => MapEntry('$key', WorkoutAmrapDraftModel.toJson(draft)),
      ),
    );
    final key = _key(executionId);
    return _serialise(() async {
      if (!await preferences.setString(key, raw)) {
        throw StateError('No se ha guardado la cuenta de vueltas.');
      }
    });
  }

  @override
  Future<void> clear(String executionId) {
    final key = _key(executionId);
    return _serialise(() async {
      if (!await preferences.remove(key)) {
        throw StateError('No se ha retirado el borrador AMRAP.');
      }
    });
  }

  Future<void> _serialise(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
