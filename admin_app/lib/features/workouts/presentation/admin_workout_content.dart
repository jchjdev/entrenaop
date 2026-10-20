import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

/// Lector único para revisar una sesión suelta o dentro de un programa.
class AdminWorkoutContent extends StatelessWidget {
  const AdminWorkoutContent({
    super.key,
    required this.template,
    this.showTitle = true,
  });
  final WorkoutTemplate template;
  final bool showTitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showTitle)
        Text(template.name, style: Theme.of(context).textTheme.headlineSmall),
      if (template.description?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(template.description!),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _summaryChip('Versión ${template.version}'),
          _summaryChip(
            '${template.blocks.length} ${template.blocks.length == 1 ? 'bloque' : 'bloques'}',
          ),
          if (template.estimatedDurationMinutes != null)
            _summaryChip('${template.estimatedDurationMinutes} min estimados'),
        ],
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < template.blocks.length; index++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _block(context, index, template.blocks[index]),
          ),
        ),
    ],
  );
  // Chip impone una sola línea por defecto; estos datos deben leerse también
  // en una tarjeta estrecha con texto ampliado.
  Widget _summaryChip(String label) =>
      Chip(label: Text(label, softWrap: true, maxLines: 3));
  Widget _block(BuildContext context, int index, WorkoutBlock block) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${index + 1}. ${block.name}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        [
          _formatLabel(block.format),
          if (block.rounds > 1) '${block.rounds} rondas',
          if (block.timeCapSeconds != null)
            'límite ${_time(block.timeCapSeconds!)}',
          if (block.restAfterSeconds > 0)
            'descanso de bloque ${_time(block.restAfterSeconds)}',
        ].join(' · '),
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < block.items.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _item(context, index, block.items[index], block.format),
        ),
    ],
  );

  Widget _item(
    BuildContext context,
    int index,
    WorkoutItem item,
    WorkoutBlockFormat format,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${index + 1}. ${item.exerciseName}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 5),
      if (format == WorkoutBlockFormat.running &&
          item.sets.length > 1 &&
          item.sets.every(
            (set) => _setText(set, format) == _setText(item.sets.first, format),
          ))
        Text('${item.sets.length} × ${_setText(item.sets.first, format)}')
      else
        for (var number = 0; number < item.sets.length; number++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${number + 1}. ${_setText(item.sets[number], format)}',
            ),
          ),
    ],
  );
}

String _setText(WorkoutSet set, WorkoutBlockFormat format) {
  final target = set.targetReps != null
      ? '${set.targetReps} rep'
      : set.targetDurationSeconds != null
      ? _time(set.targetDurationSeconds!)
      : set.targetDistanceMeters != null
      ? '${_number(set.targetDistanceMeters!)} m'
      : 'Objetivo sin definir';
  final details = <String>[target];
  if (set.targetPaceMinSecondsPerKm case final minPace?) {
    final maxPace = set.targetPaceMaxSecondsPerKm;
    details.add(
      maxPace == null || maxPace == minPace
          ? '${_time(minPace)}/km'
          : '${_time(minPace)}–${_time(maxPace)}/km',
    );
  }
  if (set.targetLoadKg != null) details.add('${_number(set.targetLoadKg!)} kg');
  if (set.usesRir && set.targetRir != null) {
    details.add('RIR ${_number(set.targetRir!)}');
  }
  if (set.recoveryType != null) {
    final measure = set.recoveryDurationSeconds != null
        ? _time(set.recoveryDurationSeconds!)
        : '${set.recoveryDistanceMeters == null ? '—' : _number(set.recoveryDistanceMeters!)} m';
    details.add('rec. ${_recoveryLabel(set.recoveryType!)} $measure');
  } else if (format != WorkoutBlockFormat.running && set.restAfterSeconds > 0) {
    details.add('descanso ${_time(set.restAfterSeconds)}');
  }
  return details.join(' · ');
}

String _time(int seconds) {
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _recoveryLabel(RunningRecoveryType type) => switch (type) {
  RunningRecoveryType.passive => 'pasiva',
  RunningRecoveryType.walking => 'andando',
  RunningRecoveryType.jogging => 'trote',
};

String _formatLabel(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.straightSets => 'Series convencionales',
  WorkoutBlockFormat.superset => 'Superserie',
  WorkoutBlockFormat.circuit => 'Circuito',
  WorkoutBlockFormat.intervals => 'Intervalos',
  WorkoutBlockFormat.emom => 'EMOM',
  WorkoutBlockFormat.amrap => 'AMRAP',
  WorkoutBlockFormat.tabata => 'Tabata 20/10',
  WorkoutBlockFormat.running => 'Carrera por tramos',
  WorkoutBlockFormat.warmUp => 'Calentamiento',
  WorkoutBlockFormat.coolDown => 'Vuelta a la calma',
};

String _number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
