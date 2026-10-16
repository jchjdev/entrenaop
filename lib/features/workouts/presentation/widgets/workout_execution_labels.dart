import '../../domain/entities/workout_amrap_draft.dart';
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
  if (workoutHasAmrap(execution)) {
    final blocks = _progressBlocks(execution);
    final resolved = blocks.values
        .where(
          (sets) => sets.every((set) => set.status != WorkoutSetStatus.pending),
        )
        .length;
    return '$resolved de ${blocks.length} '
        '${blocks.length == 1 ? 'bloque resuelto' : 'bloques resueltos'}';
  }
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

bool workoutHasAmrap(WorkoutExecution execution) =>
    execution.sets.any((set) => set.blockFormat == WorkoutBlockFormat.amrap);

Map<int, List<WorkoutExecutionSet>> _progressBlocks(
  WorkoutExecution execution,
) {
  final blocks = <int, List<WorkoutExecutionSet>>{};
  for (final set in execution.sets) {
    blocks.putIfAbsent(set.blockOrder, () => []).add(set);
  }
  return blocks;
}

double workoutProgressValue(WorkoutExecution execution) {
  if (execution.sets.isEmpty) return 0;
  if (!workoutHasAmrap(execution)) {
    return execution.resolvedSetCount / execution.sets.length;
  }
  final blocks = _progressBlocks(execution);
  return blocks.values
          .where(
            (sets) =>
                sets.every((set) => set.status != WorkoutSetStatus.pending),
          )
          .length /
      blocks.length;
}

String workoutAmrapResultLabel(
  WorkoutAmrapResult result,
  List<WorkoutExecutionSet> sequence, {
  bool includeRounds = true,
}) {
  final base =
      '${result.completedRounds} '
      '${result.completedRounds == 1 ? 'vuelta completa' : 'vueltas completas'}';
  final index = sequence.indexWhere(
    (s) => s.itemOrder == result.partialItemOrder,
  );
  if (index < 0) return base;
  final previous = sequence.take(index).map((s) => s.exerciseName).join(', ');
  return '${includeRounds ? '$base. En la siguiente: ' : 'En la siguiente vuelta: '}'
      '${previous.isEmpty ? '' : 'completaste $previous; '}'
      '${result.partialReps} repeticiones de ${sequence[index].exerciseName}.';
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

String workoutAmrapDraftSummary(
  WorkoutAmrapDraft draft,
  List<WorkoutExecutionSet> sets,
) {
  final count = int.tryParse(draft.rounds);
  if (count == null) return 'Revisa las vueltas antes de guardar.';
  final base = '$count ${count == 1 ? 'vuelta completa' : 'vueltas completas'}';
  if (!draft.hasPartial) return base;
  final index = sets.indexWhere((s) => s.itemOrder == draft.partialItemOrder);
  if (index < 0) return base;
  final reps = int.tryParse(draft.partialReps);
  final previous = sets.take(index).map((s) => s.exerciseName).join(', ');
  return '$base. En la siguiente: '
      '${previous.isEmpty ? '' : 'completaste $previous; '}'
      '${reps ?? '…'} repeticiones de ${sets[index].exerciseName}.';
}
