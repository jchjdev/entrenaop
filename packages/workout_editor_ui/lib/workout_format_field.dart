import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

import 'compact_field_layout.dart';

/// El catálogo de formatos y sus límites se mantiene igual en ambos editores.
class WorkoutFormatField extends StatelessWidget {
  const WorkoutFormatField({
    super.key,
    required this.format,
    required this.exerciseCount,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Formato',
  });

  final WorkoutBlockFormat format;
  final int exerciseCount;
  final ValueChanged<WorkoutBlockFormat> onChanged;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) => CompactFieldLayout(
    label: label,
    child: DropdownButtonFormField<WorkoutBlockFormat>(
      key: ValueKey(format),
      isExpanded: true,
      isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
      itemHeight: null,
      initialValue: format,
      selectedItemBuilder: (_) => [
        for (final name in [
          'Por series',
          'Superserie',
          'Circuito',
          'Intervalos',
          'Tabata',
          'EMOM',
          'AMRAP',
        ])
          Align(alignment: Alignment.centerLeft, child: Text(name)),
      ],
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
      decoration: InputDecoration(
        helperText: exerciseCount > 1
            ? exerciseCount > 2
                  ? 'Intervalos admite un ejercicio; superserie, dos. Mueve o quita los demás para elegirlos.'
                  : 'Intervalos de trabajo admite un solo ejercicio.'
            : null,
        helperMaxLines: 5,
      ),
      items: [
        const DropdownMenuItem(
          value: WorkoutBlockFormat.straightSets,
          child: Text('Series convencionales'),
        ),
        DropdownMenuItem(
          value: WorkoutBlockFormat.superset,
          enabled: exerciseCount <= 2 || format == WorkoutBlockFormat.superset,
          child: const Text('Superserie'),
        ),
        const DropdownMenuItem(
          value: WorkoutBlockFormat.circuit,
          child: Text('Circuito'),
        ),
        DropdownMenuItem(
          value: WorkoutBlockFormat.intervals,
          enabled: exerciseCount <= 1 || format == WorkoutBlockFormat.intervals,
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
    ),
  );
}
