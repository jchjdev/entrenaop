import '../entities/scheduled_workout_preview.dart';

abstract class ScheduledWorkoutPreviewRepository {
  Future<ScheduledWorkoutPreview> get(String scheduledId);

  /// Comprueba en servidor la revisión consultada antes de iniciar la pauta.
  Future<String> startReviewed(String scheduledId, String revision);
}
