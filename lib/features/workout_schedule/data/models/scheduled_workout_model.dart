import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';

abstract final class ScheduledWorkoutModel {
  static ScheduledWorkout fromJson(Map<String, dynamic> json) {
    return ScheduledWorkout(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      templateName: json['template_name'] as String,
      templateVersion: json['template_version'] as int,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String?,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      preparationGoalId: json['preparation_goal_id'] as String?,
      source: switch (json['source']) {
        'library' => ScheduledWorkoutSource.library,
        'user' => ScheduledWorkoutSource.user,
        'preparation' => ScheduledWorkoutSource.preparation,
        'algorithm' => ScheduledWorkoutSource.algorithm,
        'coach' => ScheduledWorkoutSource.coach,
        final value => throw FormatException('Origen desconocido: $value'),
      },
      status: switch (json['status']) {
        'planned' => ScheduledWorkoutStatus.planned,
        'in_progress' => ScheduledWorkoutStatus.inProgress,
        'completed' => ScheduledWorkoutStatus.completed,
        'abandoned' => ScheduledWorkoutStatus.abandoned,
        'skipped' => ScheduledWorkoutStatus.skipped,
        final value => throw FormatException('Estado desconocido: $value'),
      },
      executionId: json['execution_id'] as String?,
    );
  }
}
