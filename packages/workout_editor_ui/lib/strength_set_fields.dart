import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';

/// Objetivo, descanso, carga y RIR de una serie o de su valor por defecto.
/// Los datos pertenecen al editor que lo usa; este control solo edita valores.
class StrengthSetFields extends StatelessWidget {
  const StrengthSetFields({
    super.key,
    required this.targetType,
    required this.targetText,
    required this.restText,
    required this.loadText,
    required this.rirText,
    required this.onTargetChanged,
    required this.onRestChanged,
    required this.onLoadChanged,
    required this.onRirChanged,
    this.showTarget = true,
    this.showRest = true,
    this.showLoad = true,
    this.showRir = true,
    this.enabled = true,
    this.targetEnabled = true,
    this.targetOptional = false,
    this.restOptional = false,
    this.clockTarget = false,
    this.clockRest = false,
    this.validateNumbers = true,
    this.targetLabel,
    this.restLabel,
    this.loadLabel = 'Carga',
    this.rirLabel = 'RIR',
  });

  final WorkoutTargetType targetType;
  final String targetText;
  final String restText;
  final String loadText;
  final String rirText;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onRestChanged;
  final ValueChanged<String> onLoadChanged;
  final ValueChanged<String> onRirChanged;
  final bool showTarget;
  final bool showRest;
  final bool showLoad;
  final bool showRir;
  final bool enabled;
  final bool targetEnabled;
  final bool targetOptional;
  final bool restOptional;
  final bool clockTarget;
  final bool clockRest;
  final bool validateNumbers;
  final String? targetLabel;
  final String? restLabel;
  final String loadLabel;
  final String rirLabel;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      if (showTarget)
        _input(
          label:
              targetLabel ??
              switch (targetType) {
                WorkoutTargetType.repetitions => 'Repeticiones',
                WorkoutTargetType.duration => 'Tiempo',
                WorkoutTargetType.distance => 'Distancia',
              },
          value: targetText,
          onChanged: onTargetChanged,
          enabled: enabled && targetEnabled,
          clock: clockTarget,
          optional: targetOptional,
          integer: targetType != WorkoutTargetType.distance && !clockTarget,
          min: 0.01,
          max: 100000,
          suffix: clockTarget
              ? null
              : switch (targetType) {
                  WorkoutTargetType.repetitions => 'reps',
                  WorkoutTargetType.duration => 's',
                  WorkoutTargetType.distance => 'm',
                },
        ),
      if (showLoad)
        _input(
          label: loadLabel,
          value: loadText,
          onChanged: onLoadChanged,
          enabled: enabled,
          optional: true,
          min: 0,
          max: 1000,
          suffix: 'kg',
        ),
      if (showRir)
        _input(
          label: rirLabel,
          value: rirText,
          onChanged: onRirChanged,
          enabled: enabled,
          optional: true,
          min: 0,
          max: 10,
        ),
      if (showRest)
        _input(
          label: restLabel ?? 'Descanso',
          value: restText,
          onChanged: onRestChanged,
          enabled: enabled,
          clock: clockRest,
          optional: restOptional,
          integer: !clockRest,
          min: 0,
          max: 3600,
          suffix: clockRest ? null : 's',
        ),
    ],
  );

  Widget _input({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required bool enabled,
    required double min,
    required double max,
    bool optional = false,
    bool clock = false,
    bool integer = false,
    String? suffix,
  }) => SizedBox(
    width: 155,
    child: TextFormField(
      initialValue: value,
      enabled: enabled,
      keyboardType: clock
          ? TextInputType.datetime
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: !validateNumbers
          ? null
          : (text) {
              final normalized = text?.trim().replaceAll(',', '.') ?? '';
              if (normalized.isEmpty && optional) return null;
              if (clock) {
                final parts = normalized.split(':').map(int.tryParse).toList();
                if (parts.length != 2 ||
                    parts.any((part) => part == null) ||
                    parts[1]! > 59 ||
                    parts[0]! < 0) {
                  return 'Usa min:seg';
                }
                return null;
              }
              final number = double.tryParse(normalized);
              if (number == null || number < min || number > max) {
                return 'Entre ${_number(min)} y ${_number(max)}';
              }
              if (integer && number != number.roundToDouble()) {
                return 'Usa un entero';
              }
              return null;
            },
      onChanged: onChanged,
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
