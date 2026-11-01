import 'package:equatable/equatable.dart';

import '../../../workouts/domain/entities/workout_template.dart';
import 'scheduled_workout.dart';

/// Contenido de la versión asignada a esta pauta, sin crear una ejecución.
class ScheduledWorkoutPreview extends Equatable {
  const ScheduledWorkoutPreview({
    required this.scheduled,
    required this.workout,
    required this.revision,
  });

  final ScheduledWorkout scheduled;
  final WorkoutTemplate workout;
  final String revision;

  bool get canStart =>
      scheduled.status == ScheduledWorkoutStatus.planned ||
      scheduled.status == ScheduledWorkoutStatus.inProgress;

  bool get hasResult =>
      scheduled.executionId != null &&
      (scheduled.status == ScheduledWorkoutStatus.completed ||
          scheduled.status == ScheduledWorkoutStatus.abandoned);

  @override
  List<Object?> get props => [scheduled, workout, revision];
}

/// La pauta cambió después de consultarla; se exige revisar la nueva versión.
class ScheduledWorkoutPreviewChanged implements Exception {
  const ScheduledWorkoutPreviewChanged();
}
