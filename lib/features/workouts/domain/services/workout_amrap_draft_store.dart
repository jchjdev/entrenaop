import '../entities/workout_amrap_draft.dart';
export '../entities/workout_amrap_draft.dart';

abstract class WorkoutAmrapDraftStore {
  Future<Map<int, WorkoutAmrapDraft>> read(String executionId);
  Future<void> write(String executionId, Map<int, WorkoutAmrapDraft> drafts);
  Future<void> clear(String executionId);
}
