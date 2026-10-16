import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';

class MemoryWorkoutSessionDraftStore implements WorkoutSessionDraftStore {
  final _drafts = <String, Map<String, WorkoutSessionSetDraft>>{};
  @override
  Future<Map<String, WorkoutSessionSetDraft>> read(String executionId) async =>
      Map.of(_drafts[executionId] ?? {});
  @override
  Future<void> write(
    String executionId,
    Map<String, WorkoutSessionSetDraft> drafts,
  ) async {
    _drafts[executionId] = Map.of(drafts);
  }

  @override
  Future<void> clear(String executionId) async {
    _drafts.remove(executionId);
  }
}
