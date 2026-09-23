import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

/// El catálogo de formatos y sus límites se mantiene igual en ambos editores.
class WorkoutFormatField extends StatelessWidget {
  const WorkoutFormatField({
    super.key,
    required this.format,
    required this.exerciseCount,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Formato del bloque',
  });

  final WorkoutBlockFormat format;
  final int exerciseCount;
  final ValueChanged<WorkoutBlockFormat> onChanged;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<WorkoutBlockFormat>(
        key: ValueKey(format),
        isExpanded: true,
        initialValue: format,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.account_tree_outlined),
        ),
        items: [
          const DropdownMenuItem(
            value: WorkoutBlockFormat.straightSets,
            child: Text('Series convencionales'),
          ),
          const DropdownMenuItem(
            value: WorkoutBlockFormat.superset,
            child: Text('Superserie'),
          ),
          const DropdownMenuItem(
            value: WorkoutBlockFormat.circuit,
            child: Text('Circuito'),
          ),
          DropdownMenuItem(
            value: WorkoutBlockFormat.intervals,
            enabled:
                exerciseCount <= 1 || format == WorkoutBlockFormat.intervals,
            child: const Text('Intervalos de trabajo'),
          ),
          DropdownMenuItem(
            value: WorkoutBlockFormat.tabata,
            enabled: exerciseCount <= 8 || format == WorkoutBlockFormat.tabata,
            child: const Text('Tabata · 8 × 20/10'),
          ),
          const DropdownMenuItem(
            value: WorkoutBlockFormat.emom,
            child: Text('EMOM · cada minuto'),
          ),
          const DropdownMenuItem(
            value: WorkoutBlockFormat.amrap,
            child: Text('AMRAP · máximas vueltas'),
          ),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null) onChanged(value);
              }
            : null,
      );
}
