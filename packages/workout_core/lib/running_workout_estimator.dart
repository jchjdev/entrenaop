import 'package:workout_core/workout_template.dart';

class RunningWorkoutEstimate {
  const RunningWorkoutEstimate({
    required this.minimumSeconds,
    required this.maximumSeconds,
    required this.isComplete,
  });

  final double minimumSeconds;
  final double maximumSeconds;
  final bool isComplete;

  int get estimatedMinutes => ((minimumSeconds + maximumSeconds) / 2 / 60)
      .round()
      .clamp(1, 1440)
      .toInt();
}

/// Estima el tiempo prescrito sin inventar ritmos que el entrenador no indicó.
///
/// Los objetivos por duración y las recuperaciones temporizadas son exactos.
/// Una distancia necesita ritmo objetivo; una recuperación por distancia queda
/// fuera del total porque no tiene un ritmo asociado en Carrera V1.
RunningWorkoutEstimate estimateRunningWorkout(Iterable<WorkoutSetDraft> sets) {
  var minimumSeconds = 0.0;
  var maximumSeconds = 0.0;
  var isComplete = true;

  for (final set in sets) {
    if (set.targetType == WorkoutTargetType.duration) {
      minimumSeconds += set.targetValue;
      maximumSeconds += set.targetValue;
    } else if (set.targetType == WorkoutTargetType.distance &&
        set.targetPaceMinSecondsPerKm != null &&
        set.targetPaceMaxSecondsPerKm != null) {
      final distanceKm = set.targetValue / 1000;
      minimumSeconds += distanceKm * set.targetPaceMinSecondsPerKm!;
      maximumSeconds += distanceKm * set.targetPaceMaxSecondsPerKm!;
    } else {
      isComplete = false;
    }

    if (set.recoveryDurationSeconds case final recoverySeconds?) {
      minimumSeconds += recoverySeconds;
      maximumSeconds += recoverySeconds;
    } else if (set.recoveryDistanceMeters != null) {
      isComplete = false;
    }
  }

  return RunningWorkoutEstimate(
    minimumSeconds: minimumSeconds,
    maximumSeconds: maximumSeconds,
    isComplete: isComplete,
  );
}
