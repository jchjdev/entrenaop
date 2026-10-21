import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

/// Resume la receta guardada sin estimar cargas ni convertir rondas en series.
class WorkoutSummaryLine extends StatelessWidget {
  const WorkoutSummaryLine({super.key, required this.template});
  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    final items = template.blocks.expand((b) => b.items).toList();
    final conventional = template.blocks.every(
      (b) => [
        WorkoutBlockFormat.straightSets,
        WorkoutBlockFormat.warmUp,
        WorkoutBlockFormat.coolDown,
      ].contains(b.format),
    );
    final running =
        template.blocks.length == 1 &&
        template.blocks.single.format == WorkoutBlockFormat.running;
    final sets = items.fold<int>(0, (n, item) => n + item.sets.length);
    final parts = [
      '${items.length} ${items.length == 1 ? 'ejercicio' : 'ejercicios'}',
      if (running)
        '$sets ${sets == 1 ? 'tramo' : 'tramos'}'
      else if (conventional)
        '$sets ${sets == 1 ? 'serie' : 'series'}'
      else
        '${template.blocks.length} ${template.blocks.length == 1 ? 'bloque' : 'bloques'}',
      if (template.estimatedDurationMinutes case final minutes?)
        '$minutes min estimados',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(parts.join(' · ')),
    );
  }
}
