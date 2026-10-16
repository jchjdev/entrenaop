import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_template.dart';
import 'duration_input_formatter.dart';

String workoutTargetLabel(WorkoutExecutionSet set) {
  if (set.targetReps != null) return '${set.targetReps} repeticiones';
  if (set.targetDurationSeconds != null) {
    final seconds = set.targetDurationSeconds!;
    return seconds < 60 ? '$seconds segundos' : '${workoutClock(seconds)} min';
  }
  if (set.targetDistanceMeters != null) {
    return '${workoutNumber(set.targetDistanceMeters!)} metros';
  }
  return 'Objetivo configurado';
}

String workoutClock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String workoutNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

String workoutInteger(int? value) => value?.toString() ?? '';

String workoutNullableNumber(double? value) =>
    value == null ? '' : workoutNumber(value);

double? parseWorkoutDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String workoutProgressLabel(WorkoutExecution execution) {
  final completed = execution.completedSetCount;
  final skipped = execution.skippedSetCount;
  if (skipped == 0) {
    final unit =
        execution.sets.every(
          (set) => set.blockFormat == WorkoutBlockFormat.running,
        )
        ? 'tramos completados'
        : 'series completadas';
    return '$completed de ${execution.sets.length} $unit';
  }
  return '${execution.resolvedSetCount} de ${execution.sets.length} resueltas '
      '($completed completadas, $skipped omitidas)';
}

String workoutBlockFormatLabel(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.superset => 'Superserie',
  WorkoutBlockFormat.circuit => 'Circuito',
  WorkoutBlockFormat.intervals => 'Intervalo',
  WorkoutBlockFormat.tabata => 'Tabata',
  WorkoutBlockFormat.emom => 'EMOM',
  WorkoutBlockFormat.running => 'Carrera',
  _ => 'Serie',
};

String workoutPositionLabel(
  WorkoutExecutionSet set,
) => switch (set.blockFormat) {
  WorkoutBlockFormat.straightSets => 'Serie ${set.setOrder + 1}',
  WorkoutBlockFormat.superset =>
    'A${set.itemOrder + 1} · ronda ${set.roundNumber}',
  WorkoutBlockFormat.circuit =>
    'Estación ${set.itemOrder + 1} · ronda ${set.roundNumber}',
  WorkoutBlockFormat.intervals => 'Intervalo ${set.roundNumber}',
  WorkoutBlockFormat.tabata => 'Intervalo ${set.itemOrder + 1} de 8',
  WorkoutBlockFormat.emom =>
    'Minuto ${set.itemOrder + 1} · vuelta ${set.roundNumber}',
  WorkoutBlockFormat.running => 'Tramo ${set.setOrder + 1}',
  _ => '${workoutBlockFormatLabel(set.blockFormat)} · ronda ${set.roundNumber}',
};

String workoutRunningRecoveryLabel(
  RunningRecoveryType recovery,
  WorkoutExecutionSet set,
) {
  final mode = switch (recovery) {
    RunningRecoveryType.passive => 'recuperación pasiva',
    RunningRecoveryType.walking => 'recuperación andando',
    RunningRecoveryType.jogging => 'recuperación trotando',
  };
  final measure = set.recoveryDurationSeconds != null
      ? workoutClock(set.recoveryDurationSeconds!)
      : '${workoutNumber(set.recoveryDistanceMeters!)} m';
  return '$measure de $mode';
}

String? workoutTargetTimeLabel(WorkoutExecutionSet set) {
  final distance = set.targetDistanceMeters;
  final fastest = set.targetPaceMinSecondsPerKm;
  final slowest = set.targetPaceMaxSecondsPerKm;
  if (distance == null || fastest == null || slowest == null) return null;
  final fastestTime = (distance / 1000 * fastest).round();
  final slowestTime = (distance / 1000 * slowest).round();
  return fastestTime == slowestTime
      ? 'Tiempo objetivo: ${workoutClock(fastestTime)}'
      : 'Tiempo objetivo: ${workoutClock(fastestTime)}–${workoutClock(slowestTime)}';
}

String? workoutActualPaceLabel(String distanceText, String durationText) {
  final distance = parseWorkoutDecimal(distanceText);
  final duration = parseDurationInput(durationText);
  if (distance == null || distance <= 0 || duration == null || duration <= 0) {
    return null;
  }
  return workoutClock((duration * 1000 / distance).round());
}

String workoutAbandonmentReasonLabel(WorkoutAbandonmentReason reason) =>
    switch (reason) {
      WorkoutAbandonmentReason.lackOfTime => 'Falta de tiempo',
      WorkoutAbandonmentReason.tooDifficult => 'Demasiada dificultad',
      WorkoutAbandonmentReason.discomfort => 'Molestias',
      WorkoutAbandonmentReason.other => 'Otro motivo',
    };

int? parseWorkoutReps(String text) {
  final n = parseWorkoutDecimal(text);
  return n == null || !n.isFinite || n != n.roundToDouble() ? null : n.toInt();
}

String workoutResultLabel(WorkoutExecutionSet set) {
  final values = <String>[
    if (set.actualReps != null) '${set.actualReps} rep',
    if (set.actualDurationSeconds != null)
      workoutClock(set.actualDurationSeconds!),
    if (set.actualDistanceMeters != null)
      '${workoutNumber(set.actualDistanceMeters!)} m',
    if (set.actualLoadKg != null) '${workoutNumber(set.actualLoadKg!)} kg',
    if (set.actualRir != null) 'RIR ${workoutNumber(set.actualRir!)}',
    if (set.actualRpe != null) 'RPE ${workoutNumber(set.actualRpe!)}',
  ];
  return values.isEmpty
      ? 'Resultado específico registrado'
      : values.join(' · ');
}
