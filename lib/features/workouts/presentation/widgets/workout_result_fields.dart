import 'package:flutter/material.dart';

import 'duration_input_formatter.dart';
import 'workout_execution_labels.dart';

class WorkoutNumberResultField extends StatelessWidget {
  const WorkoutNumberResultField({
    super.key,
    required this.controller,
    required this.label,
    this.decimal = true,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
        validator: (value) {
          final parsed = parseWorkoutDecimal(value ?? '');
          if (parsed == null || !parsed.isFinite) {
            return 'Introduce un número válido';
          }
          if (parsed < 0) return 'El valor no puede ser negativo';
          if (!decimal && parsed != parsed.roundToDouble()) {
            return 'Introduce un número entero';
          }
          return null;
        },
      ),
    );
  }
}

class WorkoutDurationResultField extends StatelessWidget {
  const WorkoutDurationResultField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [DurationInputFormatter()],
        decoration: InputDecoration(
          labelText: '$label (min:seg)',
          hintText: '00:00',
        ),
        onChanged: onChanged,
        validator: (value) {
          final seconds = parseDurationInput(value ?? '');
          return seconds == null || seconds <= 0
              ? 'Introduce un tiempo válido'
              : null;
        },
      ),
    );
  }
}
