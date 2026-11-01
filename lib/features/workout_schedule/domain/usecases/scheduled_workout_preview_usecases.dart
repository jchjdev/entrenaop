import '../entities/scheduled_workout_preview.dart';
import '../repositories/scheduled_workout_preview_repository.dart';

class GetScheduledWorkoutPreviewUseCase {
  const GetScheduledWorkoutPreviewUseCase(this._repository);
  final ScheduledWorkoutPreviewRepository _repository;

  Future<ScheduledWorkoutPreview> call(String scheduledId) =>
      _repository.get(scheduledId);
}

class StartReviewedScheduledWorkoutUseCase {
  const StartReviewedScheduledWorkoutUseCase(this._repository);
  final ScheduledWorkoutPreviewRepository _repository;

  Future<String> call(String scheduledId, String revision) =>
      _repository.startReviewed(scheduledId, revision);
}
