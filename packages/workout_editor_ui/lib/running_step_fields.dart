import 'package:flutter/material.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/duration_input_formatter.dart';

import 'responsive_field_group.dart';

/// Campos de prescripción compartidos. Los objetivos no seleccionados no
/// ocupan espacio; el creador propietario conserva valores y validación.
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
    this.stepKind = RunningStepKind.run,
    this.onStepKindChanged,
    this.adminLabels = false,
    this.compact = false,
    this.showRecovery = true,
    this.paceEnabled,
    this.onPaceModeChanged,
    this.onRecoveryPaceModeChanged,
    this.onRecoveryTargetTypeChanged,
    this.recoveryEditor,
    this.kindLabel = 'Tipo de paso',
    this.objectiveLabel = 'Objetivo',
    this.stepKindOptions,
  });
  final RunningStepKind stepKind;
  final ValueChanged<RunningStepKind>? onStepKindChanged;
  final List<RunningStepKind>? stepKindOptions;
  final WorkoutTargetType targetType;
  final TextEditingController targetController,
      paceMinController,
      paceMaxController;
  final RunningRecoveryType? recoveryType;
  final bool recoveryByDistance;
  final TextEditingController recoveryController;
  final ValueChanged<WorkoutTargetType> onTargetTypeChanged;
  final ValueChanged<RunningRecoveryType?> onRecoveryTypeChanged;
  final ValueChanged<bool> onRecoveryMeasureChanged;
  final VoidCallback onEdited;
  final FormFieldValidator<String>? targetValidator;
  final bool adminLabels, compact, showRecovery;
  final bool? paceEnabled;
  final ValueChanged<bool>? onPaceModeChanged;
  final ValueChanged<bool>? onRecoveryPaceModeChanged;
  final ValueChanged<WorkoutTargetType>? onRecoveryTargetTypeChanged;
  final Widget? recoveryEditor;
  final String kindLabel, objectiveLabel;

  @override
  Widget build(BuildContext context) {
    final byDistance = targetType == WorkoutTargetType.distance;
    final paced =
        paceEnabled ??
        (paceMinController.text.isNotEmpty ||
            paceMaxController.text.isNotEmpty);
    final kind = DropdownButtonFormField<RunningStepKind>(
      key: ValueKey('step-kind-$stepKind'),
      initialValue: stepKind,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(labelText: kindLabel),
      items: [
        for (final k in stepKindOptions ?? RunningStepKind.values)
          DropdownMenuItem(value: k, child: Text(k.label)),
      ],
      onChanged: (value) {
        if (value != null) onStepKindChanged?.call(value);
      },
    );
    final end = DropdownButtonFormField<WorkoutTargetType>(
      key: ValueKey('target-$targetType'),
      initialValue: targetType,
      isExpanded: true,
      isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
      itemHeight: null,
      decoration: const InputDecoration(labelText: 'Cuándo termina'),
      items: [
        if (stepKind != RunningStepKind.rest || byDistance)
          const DropdownMenuItem(
            value: WorkoutTargetType.distance,
            child: Text('Distancia'),
          ),
        const DropdownMenuItem(
          value: WorkoutTargetType.duration,
          child: Text('Tiempo'),
        ),
        const DropdownMenuItem(
          value: WorkoutTargetType.manual,
          child: Text('Avance manual'),
        ),
      ],
      onChanged: (value) {
        if (value != null) onTargetTypeChanged(value);
      },
    );
    final amount = _valueField(
      targetController,
      clock: !byDistance,
      label: adminLabels
          ? (byDistance ? 'Distancia (m)' : 'Tiempo (m:ss)')
          : (byDistance ? 'Metros' : 'Min:seg'),
      validator: targetValidator,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          ResponsiveFieldGroup(
            maximumColumns: 3,
            minimumFieldWidth: 156,
            children: [
              if (onStepKindChanged != null) kind,
              end,
              if (targetType != WorkoutTargetType.manual) amount,
            ],
          )
        else ...[
          if (onStepKindChanged != null) ...[kind, const SizedBox(height: 12)],
          ResponsiveFieldGroup(
            children: [end, if (targetType != WorkoutTargetType.manual) amount],
          ),
        ],
        if (targetType == WorkoutTargetType.manual)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('En el reloj, termina al pulsar Lap.'),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          key: ValueKey('pace-mode-$paced'),
          initialValue: paced,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(labelText: objectiveLabel),
          items: [
            const DropdownMenuItem(value: false, child: Text('Sin objetivo')),
            DropdownMenuItem(
              value: true,
              enabled: stepKind != RunningStepKind.rest,
              child: const Text('Ritmo'),
            ),
          ],
          onChanged: onPaceModeChanged == null
              ? null
              : (value) {
                  if (value != null) onPaceModeChanged!(value);
                },
        ),
        if (paced) ...[
          const SizedBox(height: 12),
          ResponsiveFieldGroup(
            children: [
              _valueField(
                paceMinController,
                clock: true,
                label: adminLabels ? 'Ritmo (m:ss/km)' : 'Desde (min/km)',
              ),
              _valueField(
                paceMaxController,
                clock: true,
                label: adminLabels ? 'Hasta (m:ss/km)' : 'Hasta (min/km)',
              ),
            ],
          ),
        ],
        if (showRecovery) ...[
          const SizedBox(height: 16),
          if (recoveryEditor != null)
            recoveryEditor!
          else ...[
            DropdownButtonFormField<RunningRecoveryType?>(
              key: ValueKey('recovery-$recoveryType'),
              initialValue: recoveryType,
              isExpanded: true,
              isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Recuperación'),
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
              const SizedBox(height: 12),
              ResponsiveFieldGroup(
                children: [
                  if (onRecoveryTargetTypeChanged != null)
                    _controlledChoice<WorkoutTargetType>(
                      key: ValueKey(
                        'attached-recovery-end-$recoveryByDistance',
                      ),
                      value: recoveryByDistance
                          ? WorkoutTargetType.distance
                          : WorkoutTargetType.duration,
                      label: 'Cuándo termina',
                      items: [
                        const DropdownMenuItem(
                          value: WorkoutTargetType.duration,
                          child: Text('Tiempo'),
                        ),
                        if (recoveryType != RunningRecoveryType.passive)
                          const DropdownMenuItem(
                            value: WorkoutTargetType.distance,
                            child: Text('Distancia'),
                          ),
                        const DropdownMenuItem(
                          value: WorkoutTargetType.manual,
                          child: Text('Avance manual'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onRecoveryTargetTypeChanged!(value);
                      },
                    )
                  else if (recoveryType != RunningRecoveryType.passive)
                    DropdownButtonFormField<bool>(
                      key: ValueKey('measure-$recoveryByDistance'),
                      initialValue: recoveryByDistance,
                      isExpanded: true,
                      isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Cuándo termina',
                      ),
                      items: const [
                        DropdownMenuItem(value: false, child: Text('Tiempo')),
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
                        ? (recoveryByDistance
                              ? 'Recuperación (m)'
                              : 'Recuperación (m:ss)')
                        : (recoveryByDistance ? 'Metros' : 'Min:seg'),
                  ),
                ],
              ),
              if (onRecoveryPaceModeChanged != null) ...[
                const SizedBox(height: 12),
                _controlledChoice<bool>(
                  key: const ValueKey('attached-recovery-objective'),
                  value: false,
                  label: 'Objetivo',
                  items: [
                    const DropdownMenuItem(
                      value: false,
                      child: Text('Sin objetivo'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      enabled: recoveryType != RunningRecoveryType.passive,
                      child: const Text('Ritmo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onRecoveryPaceModeChanged!(value);
                  },
                ),
              ],
            ],
          ],
        ],
      ],
    );
  }

  Widget _controlledChoice<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => InputDecorator(
    key: key,
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        itemHeight: null,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _valueField(
    TextEditingController controller, {
    required bool clock,
    required String label,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: clock
        ? TextInputType.number
        : const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: clock ? const [DurationInputFormatter()] : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: clock ? '00:00' : null,
    ),
    onChanged: (_) => onEdited(),
    validator: validator,
  );
}
