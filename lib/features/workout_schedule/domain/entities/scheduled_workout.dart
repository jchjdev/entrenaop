import 'package:equatable/equatable.dart';
import 'package:workout_core/device_activity_summary.dart';

enum ScheduledWorkoutSource { library, user, preparation, algorithm, coach }

enum ScheduledWorkoutStatus {
  planned,
  inProgress,
  completed,
  abandoned,
  skipped,
}

class ScheduledWorkout extends Equatable {
  const ScheduledWorkout({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.templateVersion,
    required this.scheduledDate,
    required this.source,
    required this.status,
    this.preparationGoalId,
    this.scheduledTime,
    this.estimatedDurationMinutes,
    this.executionId,
    this.coachNote,
    this.coachName,
    this.isSelfAssigned = false,
    this.appleResults = const [],
  });

  final String id;
  final String templateId;
  final String templateName;
  final int templateVersion;
  final DateTime scheduledDate;
  final String? scheduledTime;
  final int? estimatedDurationMinutes;
  final ScheduledWorkoutSource source;
  final ScheduledWorkoutStatus status;
  final String? preparationGoalId;
  final String? executionId;
  final String? coachNote;
  final String? coachName;
  final bool isSelfAssigned;
  final List<DeviceActivitySummary> appleResults;

  @override
  List<Object?> get props => [
    id,
    templateId,
    templateName,
    templateVersion,
    scheduledDate,
    scheduledTime,
    estimatedDurationMinutes,
    source,
    status,
    preparationGoalId,
    executionId,
    coachNote,
    coachName,
    isSelfAssigned,
    appleResults,
  ];
}
