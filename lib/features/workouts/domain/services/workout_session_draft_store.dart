import '../entities/workout_session_set_draft.dart';
export '../entities/workout_session_set_draft.dart';

abstract class WorkoutSessionDraftStore {
  Future<Map<String, WorkoutSessionSetDraft>> read(String executionId);
  Future<void> write(
    String executionId,
    Map<String, WorkoutSessionSetDraft> drafts,
  );
  Future<void> clear(String executionId);
}
