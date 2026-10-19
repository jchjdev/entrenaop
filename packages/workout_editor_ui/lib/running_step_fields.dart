import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/duration_input_formatter.dart';

import 'responsive_field_group.dart';

/// Campos de un tramo de carrera compartidos por el editor personal y el panel.
/// La aplicación propietaria conserva el estado, la persistencia y los permisos.
class RunningStepFields extends StatelessWidget {
  const RunningStepFields({
    super.key,
    required this.targetType,
    required this.targetController,
    required this.paceMinController,
    required this.paceMaxController,
    required this.recoveryType,
    required this.recoveryByDistance,
    required this.recoveryController,
    required this.onTargetTypeChanged,
    required this.onRecoveryTypeChanged,
    required this.onRecoveryMeasureChanged,
    required this.onEdited,
    this.targetValidator,
    this.adminLabels = false,
  });

  final WorkoutTargetType targetType;
  final TextEditingController targetController;
  final TextEditingController paceMinController;
  final TextEditingController paceMaxController;
  final RunningRecoveryType? recoveryType;
  final bool recoveryByDistance;
  final TextEditingController recoveryController;
  final ValueChanged<WorkoutTargetType> onTargetTypeChanged;
  final ValueChanged<RunningRecoveryType?> onRecoveryTypeChanged;
  final ValueChanged<bool> onRecoveryMeasureChanged;
  final VoidCallback onEdited;
  final FormFieldValidator<String>? targetValidator;
  final bool adminLabels;

  @override
  Widget build(BuildContext context) {
    final byDistance = targetType == WorkoutTargetType.distance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveFieldGroup(
          children: [
            DropdownButtonFormField<WorkoutTargetType>(
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontSize: 16),
              key: ValueKey('target-$targetType'),
              initialValue: targetType,
              isExpanded: true,
              isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: adminLabels ? 'Tipo de objetivo' : 'Objetivo',
              ),
              items: const [
                DropdownMenuItem(
                  value: WorkoutTargetType.distance,
                  child: Text('Distancia'),
                ),
                DropdownMenuItem(
                  value: WorkoutTargetType.duration,
                  child: Text('Duración'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onTargetTypeChanged(value);
              },
            ),
            _valueField(
              targetController,
              clock: !byDistance,
              label: adminLabels
                  ? byDistance
                        ? 'Distancia (m)'
                        : 'Tiempo (m:ss)'
                  : byDistance
                  ? 'Metros'
                  : 'Min:seg',
              validator: targetValidator,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!adminLabels) ...[
          const Text('Ritmo opcional', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 7),
        ],
        ResponsiveFieldGroup(
          children: [
            _valueField(
              paceMinController,
              clock: true,
              label: adminLabels ? 'Ritmo (m:ss/km)' : 'Desde (min/km)',
              hint: adminLabels ? null : '5:00',
            ),
            _valueField(
              paceMaxController,
              clock: true,
              label: adminLabels ? 'Hasta (m:ss/km)' : 'Hasta (min/km)',
              hint: adminLabels ? null : '5:20',
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RunningRecoveryType?>(
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
          key: ValueKey('recovery-$recoveryType'),
          initialValue: recoveryType,
          isExpanded: true,
          isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
          itemHeight: null,
          decoration: InputDecoration(labelText: 'Recuperación'),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(adminLabels ? 'Ninguna' : 'Sin recuperación'),
            ),
            const DropdownMenuItem(
              value: RunningRecoveryType.passive,
              child: Text('Pasiva'),
            ),
            const DropdownMenuItem(
              value: RunningRecoveryType.walking,
              child: Text('Andando'),
            ),
            DropdownMenuItem(
              value: RunningRecoveryType.jogging,
              child: Text(adminLabels ? 'Trote' : 'Trotando'),
            ),
          ],
          onChanged: onRecoveryTypeChanged,
        ),
        if (recoveryType != null) ...[
          const SizedBox(height: 10),
          ResponsiveFieldGroup(
            children: [
              if (recoveryType != RunningRecoveryType.passive)
                DropdownButtonFormField<bool>(
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontSize: 16),
                  key: ValueKey('measure-$recoveryByDistance'),
                  initialValue: recoveryByDistance,
                  isExpanded: true,
                  isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Medida'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Duración')),
                    DropdownMenuItem(value: true, child: Text('Distancia')),
                  ],
                  onChanged: (value) {
                    if (value != null) onRecoveryMeasureChanged(value);
                  },
                ),
              _valueField(
                recoveryController,
                clock: !recoveryByDistance,
                label: adminLabels
                    ? recoveryByDistance
                          ? 'Recuperación (m)'
                          : 'Recuperación (m:ss)'
                    : recoveryByDistance
                    ? 'Metros'
                    : 'Min:seg',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _valueField(
    TextEditingController controller, {
    required bool clock,
    required String label,
    String? hint,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: clock
        ? TextInputType.number
        : const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: clock ? const [DurationInputFormatter()] : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: clock ? '00:00' : hint,
    ),
    onChanged: (_) => onEdited(),
    validator: validator,
  );
}
