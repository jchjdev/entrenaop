import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';

abstract class WorkoutScheduleRepository {
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end);

  Future<String> schedule(
    String templateId,
    DateTime date, {
    String? time,
    String? preparationGoalId,
  });

  Future<void> reschedule(String scheduledId, DateTime date, {String? time});

  Future<void> cancel(String scheduledId);

  Future<String> start(String scheduledId);
}
