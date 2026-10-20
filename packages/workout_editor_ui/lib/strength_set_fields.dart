import 'package:flutter/material.dart';

import 'duration_input_formatter.dart';
import 'workout_effort_field.dart';
import 'responsive_field_group.dart';

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
    this.inheritEmptyValues = false,
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

  /// Las excepciones vacías conservan el valor común, no equivalen a cero.
  final bool inheritEmptyValues;

  @override
  Widget build(BuildContext context) {
    // El ancho depende del contenido: un reloj o un valor largo nunca debe
    // competir con un sufijo. La escala la aplica el grupo compartido.
    var minimum = 72.0;
    final labels = [
      if (showTarget) targetLabel ?? _targetLabel,
      if (showLoad) loadLabel,
      if (showRir && targetType.supportsRir) rirLabel,
      if (showRest) restLabel ?? 'Descanso',
    ];
    final values = [
      if (showTarget)
        _displayValue(
          targetText,
          clockTarget || targetType == WorkoutTargetType.duration,
        ),
      if (showLoad) loadText,
      if (showRir && targetType.supportsRir) rirText,
      if (showRest) _displayValue(restText, true),
    ];
    for (final text in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontSize: 10.5),
        ),
        textDirection: Directionality.of(context),
      )..layout();
      minimum = minimum < painter.width + 16 ? painter.width + 16 : minimum;
      painter.dispose();
    }
    for (final text in values) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontSize: 16),
        ),
        textDirection: Directionality.of(context),
      )..layout();
      minimum = minimum < painter.width + 16 ? painter.width + 16 : minimum;
      painter.dispose();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ResponsiveFieldGroup(
          minimumFieldWidth: minimum,
          maximumColumns: 4,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final field in _fields())
              Padding(
                // La etiqueta flotante necesita espacio propio, también cuando
                // el grupo está debajo de una cabecera o salta a otra fila.
                padding: EdgeInsets.only(
                  top: MediaQuery.textScalerOf(context).scale(12),
                ),
                child: field,
              ),
          ],
        ),
      ),
    );
  }

  String get _targetLabel => switch (targetType) {
    WorkoutTargetType.repetitions => 'Reps',
    WorkoutTargetType.duration => 'Tiempo',
    WorkoutTargetType.distance => 'Distancia',
  };

  String _displayValue(String value, bool clock) =>
      clock && num.tryParse(value) != null
      ? formatDurationSeconds(num.parse(value))
      : value;

  List<Widget> _fields() => [
    if (showTarget)
      _input(
        label: targetLabel ?? _targetLabel,
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
    if (showRir && targetType.supportsRir)
      WorkoutEffortField(
        compact: true,
        label: rirLabel,
        minimum: 0,
        value: double.tryParse(rirText.replaceAll(',', '.')),
        emptyText: inheritEmptyValues ? 'Común' : null,
        enabled: enabled,
        onChanged: (value) => onRirChanged(value == null ? '' : _number(value)),
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
  ];

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
  }) => TextFormField(
    key: ValueKey('$label:$clock:$suffix'),
    initialValue: suffix == 's' && num.tryParse(value) != null
        ? formatDurationSeconds(num.parse(value))
        : value,
    enabled: enabled,
    style: const TextStyle(
      fontSize: 16,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    keyboardType: clock || suffix == 's'
        ? TextInputType.number
        : const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: clock || suffix == 's'
        ? const [DurationInputFormatter()]
        : null,
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperText: clock || suffix == 's' ? 'min:seg' : suffix ?? ' ',
      hintText: inheritEmptyValues
          ? 'Común'
          : clock || suffix == 's'
          ? '00:00'
          : null,
    ),
    validator: !validateNumbers
        ? null
        : (text) {
            final normalized = text?.trim().replaceAll(',', '.') ?? '';
            if (normalized.isEmpty && optional) return null;
            if (clock || suffix == 's') {
              final seconds = parseDurationInput(normalized);
              return seconds == null || seconds < min || seconds > max
                  ? 'Usa un tiempo entre ${formatDurationSeconds(min)} y ${formatDurationSeconds(max)}'
                  : null;
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
    // Conserva el contrato del editor: los controles antes expresados en
    // segundos entregan segundos, aunque la interfaz muestre un reloj.
    onChanged: suffix == 's' && !clock
        ? (text) => onChanged(parseDurationInput(text)?.toString() ?? text)
        : onChanged,
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
