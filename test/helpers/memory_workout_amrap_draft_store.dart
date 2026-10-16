import 'package:entrenaop/features/workouts/domain/services/workout_amrap_draft_store.dart';

class MemoryWorkoutAmrapDraftStore implements WorkoutAmrapDraftStore {
  final drafts = <String, Map<int, WorkoutAmrapDraft>>{};
  bool failWrite = false;
  @override
  Future<Map<int, WorkoutAmrapDraft>> read(String executionId) async =>
      Map.of(drafts[executionId] ?? {});
  @override
  Future<void> write(
    String executionId,
    Map<int, WorkoutAmrapDraft> value,
  ) async {
    if (failWrite) throw StateError('Disco no disponible');
    drafts[executionId] = Map.of(value);
  }

  @override
  Future<void> clear(String executionId) async => drafts.remove(executionId);
}
