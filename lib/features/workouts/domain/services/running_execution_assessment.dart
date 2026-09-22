import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

enum RunningExecutionAssessment { onTarget, changed, incomplete }

RunningExecutionAssessment assessRunningExecution(
  Iterable<WorkoutExecutionSet> sets,
) {
  final runningSets = sets
      .where((set) => set.blockFormat == WorkoutBlockFormat.running)
      .toList(growable: false);
  if (runningSets.isEmpty ||
      runningSets.any((set) => set.status != WorkoutSetStatus.completed)) {
    return RunningExecutionAssessment.incomplete;
  }
  return runningSets.every(_matchesPrescription)
      ? RunningExecutionAssessment.onTarget
      : RunningExecutionAssessment.changed;
}

bool _matchesPrescription(WorkoutExecutionSet set) {
  final duration = set.actualDurationSeconds;
  final distance = set.actualDistanceMeters;
  if (duration == null || distance == null || duration <= 0 || distance <= 0) {
    return false;
  }
  if (set.targetDistanceMeters case final target?) {
    if (!_withinTolerance(distance, target, 0.01)) return false;
  }
  if (set.targetDurationSeconds case final target?) {
    if (!_withinTolerance(duration.toDouble(), target.toDouble(), 0.02)) {
      return false;
    }
  }
  final fastest = set.targetPaceMinSecondsPerKm;
  final slowest = set.targetPaceMaxSecondsPerKm;
  if (fastest != null && slowest != null) {
    final pace = duration * 1000 / distance;
    if (pace < fastest || pace > slowest) return false;
  }
  if (set.recoveryDurationSeconds case final target?) {
    final actual = set.actualRecoveryDurationSeconds;
    if (actual == null ||
        !_withinTolerance(actual.toDouble(), target.toDouble(), 0.05)) {
      return false;
    }
  }
  if (set.recoveryDistanceMeters case final target?) {
    final actual = set.actualRecoveryDistanceMeters;
    if (actual == null || !_withinTolerance(actual, target, 0.05)) return false;
  }
  return true;
}

bool _withinTolerance(double actual, double target, double tolerance) =>
    (actual - target).abs() <= target * tolerance;

String runningAssessmentLabel(RunningExecutionAssessment assessment) =>
    switch (assessment) {
      RunningExecutionAssessment.onTarget => 'Cumplida dentro del objetivo',
      RunningExecutionAssessment.changed => 'Cumplida con desviaciones',
      RunningExecutionAssessment.incomplete => 'Parcialmente cumplida',
    };
