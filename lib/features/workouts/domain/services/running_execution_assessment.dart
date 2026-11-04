import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

enum RunningExecutionAssessment {
  onTarget,
  timeOnly,
  slightPaceDifference,
  changed,
  incomplete,
}

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
  if (!runningSets.every(_matchesPrescription)) {
    return runningSets.every(
      (set) => _matchesPrescription(set, allowSmallPaceDifference: true),
    )
        ? RunningExecutionAssessment.slightPaceDifference
        : RunningExecutionAssessment.changed;
  }
  return runningSets.any((set) => set.actualDistanceMeters == null)
      ? RunningExecutionAssessment.timeOnly
      : RunningExecutionAssessment.onTarget;
}

bool _matchesPrescription(
  WorkoutExecutionSet set, {
  bool allowSmallPaceDifference = false,
}) {
  final duration = set.measuredDurationSeconds;
  final distance = set.actualDistanceMeters;
  if (duration == null ||
      duration <= 0 ||
      (distance == null && !set.manualDistanceOptional) ||
      (distance != null &&
          (distance < 0 ||
              (distance == 0 && set.runningStep?.kind != RunningStepKind.rest)))) {
    return false;
  }
  if (set.targetDistanceMeters case final target?) {
    if (distance == null || !_withinTolerance(distance, target, 0.01)) {
      return false;
    }
  }
  if (set.targetDurationSeconds case final target?) {
    if (!_withinTolerance(duration.toDouble(), target.toDouble(), 0.02)) {
      return false;
    }
  }
  final fastest = set.targetPaceMinSecondsPerKm;
  final slowest = set.targetPaceMaxSecondsPerKm;
  if (fastest != null && slowest != null && distance != null) {
    final pace = duration * 1000 / distance;
    if ((pace < fastest || pace > slowest) &&
        !(allowSmallPaceDifference &&
            _withinPaceMargin(pace, fastest, slowest))) {
      return false;
    }
  }
  if (set.recoveryDurationSeconds case final target?) {
    final actual = set.measuredRecoverySeconds;
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

// Márgenes de ritmo de running_policy_v1. El motor evalúa además la sesión
// completa, sus recuperaciones y el esfuerzo declarado.
bool _withinPaceMargin(double pace, int fastest, int slowest) =>
    pace >= fastest * 0.97 && pace <= slowest * 1.05;

String runningAssessmentLabel(RunningExecutionAssessment assessment) =>
    switch (assessment) {
      RunningExecutionAssessment.onTarget => 'Marca registrada según la pauta',
      RunningExecutionAssessment.timeOnly => 'Tiempos registrados · ritmo sin medir',
      RunningExecutionAssessment.slightPaceDifference =>
        'Registrado · ajusta un poco el ritmo',
      RunningExecutionAssessment.changed => 'Diferencias con la pauta',
      RunningExecutionAssessment.incomplete => 'Registro parcial',
    };

/// Explica la comparación existente sin convertirla en una nota deportiva.
/// El historial conserva segundos enteros; no equivale al análisis de Garmin.
List<String> runningAssessmentDifferences(Iterable<WorkoutExecutionSet> sets) {
  final differences = <String>[];
  for (final set in sets.where(
    (s) => s.blockFormat == WorkoutBlockFormat.running,
  )) {
    if (set.status != WorkoutSetStatus.completed) continue;
    final label = set.runningStep?.kind.label ?? 'Tramo';
    final fields = <String>[];
    if (set.targetDurationSeconds case final target?) {
      final actual = set.measuredDurationSeconds;
      if (actual != null &&
          !_withinTolerance(actual.toDouble(), target.toDouble(), .02)) {
        fields.add('tiempo registrado distinto del previsto');
      }
    }
    if (set.targetDistanceMeters case final target?) {
      final actual = set.actualDistanceMeters;
      if (actual != null && !_withinTolerance(actual, target, .01)) {
        fields.add('distancia distinta');
      }
    }
    final seconds = set.measuredDurationSeconds,
        meters = set.actualDistanceMeters;
    if (seconds != null &&
        meters != null &&
        meters > 0 &&
        set.targetPaceMinSecondsPerKm != null &&
        set.targetPaceMaxSecondsPerKm != null) {
      final pace = seconds * 1000 / meters;
      final fastest = set.targetPaceMinSecondsPerKm!;
      final slowest = set.targetPaceMaxSecondsPerKm!;
      if (pace < fastest || pace > slowest) {
        fields.add(
          _withinPaceMargin(pace, fastest, slowest)
              ? pace < fastest
                    ? 'ritmo ligeramente rápido, prueba a aflojar un poco'
                    : 'ritmo ligeramente lento, prueba a acelerar un poco'
              : 'ritmo medio fuera del intervalo pautado',
        );
      }
    }
    if (set.recoveryDurationSeconds case final target?) {
      final actual = set.measuredRecoverySeconds;
      if (actual == null ||
          !_withinTolerance(actual.toDouble(), target.toDouble(), .05)) {
        fields.add('recuperación distinta o sin registro');
      }
    }
    if (set.recoveryDistanceMeters case final target?) {
      final actual = set.actualRecoveryDistanceMeters;
      if (actual == null || !_withinTolerance(actual, target, .05)) {
        fields.add('distancia de recuperación distinta o sin registro');
      }
    }
    if (fields.isEmpty && !_matchesPrescription(set)) {
      fields.add('datos insuficientes para comparar');
    }
    if (fields.isNotEmpty) {
      differences.add('$label (${set.setOrder + 1}): ${fields.join('; ')}.');
    }
  }
  return differences;
}
