import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workout_core/workout_template.dart';

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
    this.clockFormatter,
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
  final TextInputFormatter? clockFormatter;
  final FormFieldValidator<String>? targetValidator;
  final bool adminLabels;

  @override
  Widget build(BuildContext context) {
    final byDistance = targetType == WorkoutTargetType.distance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<WorkoutTargetType>(
                key: ValueKey('target-$targetType'),
                initialValue: targetType,
                isExpanded: true,
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _valueField(
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
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!adminLabels) ...[
          const Text('Ritmo opcional', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 7),
        ],
        Row(
          children: [
            Expanded(
              child: _valueField(
                paceMinController,
                clock: true,
                label: adminLabels ? 'Ritmo (m:ss/km)' : 'Desde (min/km)',
                hint: adminLabels ? null : '5:00',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _valueField(
                paceMaxController,
                clock: true,
                label: adminLabels ? 'Hasta (m:ss/km)' : 'Hasta (min/km)',
                hint: adminLabels ? null : '5:20',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RunningRecoveryType?>(
          key: ValueKey('recovery-$recoveryType'),
          initialValue: recoveryType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: adminLabels ? 'Recuperación' : 'Recuperación posterior',
          ),
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
          Row(
            children: [
              if (recoveryType != RunningRecoveryType.passive) ...[
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    key: ValueKey('measure-$recoveryByDistance'),
                    initialValue: recoveryByDistance,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Medida'),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('Duración')),
                      DropdownMenuItem(value: true, child: Text('Distancia')),
                    ],
                    onChanged: (value) {
                      if (value != null) onRecoveryMeasureChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _valueField(
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
        ? TextInputType.datetime
        : const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: clock && clockFormatter != null ? [clockFormatter!] : null,
    decoration: InputDecoration(labelText: label, hintText: hint),
    onChanged: (_) => onEdited(),
    validator: validator,
  );
}
