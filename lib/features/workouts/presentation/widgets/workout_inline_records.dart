import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_session_set_draft.dart';
import '../../domain/entities/workout_template.dart';
import 'duration_input_formatter.dart';
import 'workout_execution_labels.dart';

typedef InlineRecordUpdate = Future<void> Function(
  WorkoutSetResultInput result,
  Map<String, String> fields,
  bool hasMeasuredResult,
);
typedef InlineRecordConfirm = Future<bool> Function(
  WorkoutSetResultInput result,
  Map<String, String> fields,
);

enum WorkoutInlineField {
  reps('Reps', 'Repeticiones'),
  duration('Tiempo', 'Tiempo en min:seg'),
  distance('Metros', 'Metros'),
  load('Peso (kg)', 'Peso en kg'),
  rir('RIR', 'RIR'),
  rpe('RPE', 'RPE');

  const WorkoutInlineField(this.label, this.accessibleLabel);
  final String label;
  final String accessibleLabel;

  static List<WorkoutInlineField>? forSet(WorkoutExecutionSet set) {
    // Las sesiones guiadas conservan sus controles y secuencias propios.
    if (set.blockFormat != WorkoutBlockFormat.straightSets ||
        set.performancePrescription != null ||
        set.recoveryDurationSeconds != null ||
        set.recoveryDistanceMeters != null ||
        (set.resultSource != null &&
            set.resultSource != WorkoutResultSource.manual)) {
      return null;
    }
    final measures = [
      if (set.targetReps != null) reps,
      if (set.targetDurationSeconds != null) duration,
      if (set.targetDistanceMeters != null) distance,
    ];
    if (measures.length != 1) return null;
    return [
      ...measures,
      if (set.supportsLoadRecording) load,
      if (set.usesRir && set.targetRir != null) rir,
      if (set.targetRpe != null) rpe,
    ];
  }

  num? parse(String text) => switch (this) {
    reps => parseWorkoutReps(text),
    duration => parseDurationInput(text),
    _ => parseWorkoutDecimal(text),
  };

  String resultText(WorkoutExecutionSet set, WorkoutSessionSetDraft? draft) {
    final text = draft?.fields[name];
    if (text != null) return text;
    final result = draft?.result;
    final value = switch (this) {
      reps => draft == null ? set.actualReps : result?.actualReps,
      duration =>
        draft == null
            ? set.actualDurationSeconds
            : result?.actualDurationSeconds,
      distance =>
        draft == null ? set.actualDistanceMeters : result?.actualDistanceMeters,
      load => draft == null ? set.actualLoadKg : result?.actualLoadKg,
      rir => draft == null ? set.actualRir : result?.actualRir,
      rpe => draft == null ? set.actualRpe : result?.actualRpe,
    };
    if (value == null) return '';
    return this == duration
        ? workoutClock(value.toInt())
        : workoutNumber(value.toDouble());
  }
}

/// Encabezado y filas comparten las mismas columnas, incluso sin datos o ✓.
class WorkoutInlineRecordColumns extends StatelessWidget {
  const WorkoutInlineRecordColumns({
    super.key,
    required this.leading,
    required this.cells,
    this.action,
  });

  static const double inset = 8;
  static const double cellHeight = kMinInteractiveDimension;
  static const double _edgeWidth = kMinInteractiveDimension;
  static const double _maxCellWidth = 92;

  static double minimumWidth(int count) =>
      2 * (inset + _edgeWidth) + 58 * count;

  final Widget leading;
  final List<Widget> cells;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 2 * _edgeWidth + _maxCellWidth * cells.length,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _edgeWidth,
            child: Center(child: leading),
          ),
          for (final cell in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: cell,
              ),
            ),
          SizedBox(width: _edgeWidth, child: action),
        ],
      ),
    ),
  );
}

class WorkoutInlineRecordRow extends StatefulWidget {
  const WorkoutInlineRecordRow({
    super.key,
    required this.set,
    required this.fields,
    required this.draft,
    required this.current,
    required this.editable,
    required this.enabled,
    required this.compact,
    required this.onUpdate,
    required this.onConfirm,
    this.waitingStatus,
  });

  final WorkoutExecutionSet set;
  final List<WorkoutInlineField> fields;
  final WorkoutSessionSetDraft? draft;
  final bool current, editable, enabled, compact;
  final InlineRecordUpdate onUpdate;
  final InlineRecordConfirm onConfirm;
  final String? waitingStatus;

  @override
  State<WorkoutInlineRecordRow> createState() => _WorkoutInlineRecordRowState();
}

class _WorkoutInlineRecordRowState extends State<WorkoutInlineRecordRow> {
  late final _initialText = {
    for (final field in widget.fields)
      field: field.resultText(widget.set, widget.draft),
  };
  late final _controllers = {
    for (final entry in _initialText.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  bool _saving = false;
  bool _measureEdited = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _fields => {
    ...?widget.draft?.fields,
    for (final entry in _controllers.entries) entry.key.name: entry.value.text,
  };

  WorkoutSetResultInput _result({bool forDraft = false}) {
    num? value(WorkoutInlineField field) =>
        field.parse(_controllers[field]?.text ?? '');
    final rpe = value(WorkoutInlineField.rpe);
    return WorkoutSetResultInput(
      resultId: widget.set.id,
      actualReps: value(WorkoutInlineField.reps)?.toInt(),
      actualDurationSeconds: value(WorkoutInlineField.duration)?.toInt(),
      actualDistanceMeters: value(WorkoutInlineField.distance)?.toDouble(),
      actualLoadKg: value(WorkoutInlineField.load)?.toDouble(),
      actualRir: _controllers.containsKey(WorkoutInlineField.rir)
          ? value(WorkoutInlineField.rir)?.toDouble()
          : forDraft
          ? widget.draft?.result.actualRir ?? widget.set.actualRir
          : null,
      actualRpe: _hasInvalidRpe ? null : rpe?.toDouble(),
    );
  }

  bool get _hasInvalidRpe {
    final text = _controllers[WorkoutInlineField.rpe]?.text.trim() ?? '';
    if (text.isEmpty || parseWorkoutReps(text) != null) return false;
    final draft = widget.draft;
    final previousRpe = draft == null
        ? widget.set.actualRpe
        : draft.result.actualRpe;
    return text != _initialText[WorkoutInlineField.rpe] || previousRpe == null;
  }

  bool get _canConfirm {
    if (!widget.enabled || _saving || _hasInvalidRpe) return false;
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      if (entry.key.parse(text) == null) return false;
    }
    return WorkoutSessionSetDraft(result: _result()).canConfirm(widget.set);
  }

  void _changed(WorkoutInlineField field) {
    setState(() {
      if (field == widget.fields.first) _measureEdited = true;
    });
    final draft = widget.draft;
    unawaited(
      widget.onUpdate(
        _result(forDraft: true),
        _fields,
        _measureEdited ||
            draft?.hasMeasuredResult == true ||
            draft?.saved == true ||
            (draft == null && widget.set.status == WorkoutSetStatus.completed),
      ),
    );
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    final result = _result();
    final fields = _fields;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    await widget.onConfirm(result, fields);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tapToEdit = !kIsWeb && theme.platform == TargetPlatform.iOS;
    final draft = widget.draft;
    final set = widget.set;
    final position = workoutPositionLabel(set);
    final completed = set.status == WorkoutSetStatus.completed;
    final skipped = set.status == WorkoutSetStatus.skipped;
    final pending = completed && (draft?.hasUnconfirmedData ?? false);
    final status =
        widget.waitingStatus ??
        (widget.current
            ? 'Actual'
            : pending
            ? 'Datos por confirmar'
            : completed
            ? draft?.needsCorrection == true
                  ? 'Retoques por sincronizar'
                  : 'Registrada'
            : skipped
            ? 'Omitida'
            : 'Por realizar');
    final showCheck = widget.editable && (widget.current || pending);
    final title = Text(
      widget.compact ? (set.setOrder + 1).toString() : position,
      semanticsLabel: widget.compact ? position : null,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: widget.current ? theme.colorScheme.primary : null,
      ),
    );
    final check = showCheck
        ? IconButton(
            tooltip: widget.current
                ? 'Terminar $position'
                : 'Confirmar $position',
            onPressed: _canConfirm ? _confirm : null,
            icon: const Icon(Icons.check_rounded, size: 22),
          )
        : null;
    final cells = widget.fields.map((field) {
      if (!widget.editable) {
        final value = skipped ? '' : field.resultText(set, draft);
        return SizedBox(
          height: WorkoutInlineRecordColumns.cellHeight,
          child: Center(
            child: Text(
              value.isEmpty ? '—' : value,
              key: ValueKey('inline-${set.id}-${field.name}-value'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: tapToEdit
                    ? null
                    : const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      }
      final label = '${field.accessibleLabel}, $position';
      final controller = _controllers[field]!;
      final enabled = widget.enabled && !_saving;
      final alignment = widget.compact ? TextAlign.center : TextAlign.start;
      final style = theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: tapToEdit ? null : const [FontFeature.tabularFigures()],
      );
      final decoration = InputDecoration(
        labelText: widget.compact ? null : field.label,
        hintText: field == WorkoutInlineField.duration ? '0:00' : '—',
        isDense: widget.compact ? false : null,
        enabledBorder: widget.compact
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : null,
        constraints: widget.compact
            ? const BoxConstraints.tightFor(
                height: WorkoutInlineRecordColumns.cellHeight,
              )
            : null,
        contentPadding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 6)
            : null,
      );
      Widget editor(FocusNode? focusNode) => Semantics(
        label: label,
        child: TextField(
          key: ValueKey('inline-${set.id}-${field.name}'),
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textAlign: alignment,
          textAlignVertical: TextAlignVertical.center,
          style: style,
          keyboardType: TextInputType.numberWithOptions(
            decimal:
                field != WorkoutInlineField.reps &&
                field != WorkoutInlineField.duration &&
                field != WorkoutInlineField.rpe,
          ),
          inputFormatters: field == WorkoutInlineField.duration
              ? const [DurationInputFormatter()]
              : null,
          decoration: decoration,
          onChanged: (_) => _changed(field),
        ),
      );
      return tapToEdit
          ? _InlineRecordTapToEdit(
              key: ValueKey('inline-cell-${set.id}-${field.name}'),
              controller: controller,
              enabled: enabled,
              label: label,
              alignment: alignment,
              style: style,
              decoration: decoration,
              buildEditor: editor,
            )
          : editor(null);
    }).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.current
              ? theme.colorScheme.primary.withValues(alpha: .08)
              : null,
          border: widget.current
              ? Border.all(color: theme.colorScheme.primary)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WorkoutInlineRecordColumns.inset,
            vertical: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.compact)
                WorkoutInlineRecordColumns(
                  leading: title,
                  cells: cells,
                  action:
                      check ??
                      (completed
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : null),
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: title),
                    ?check,
                  ],
                ),
                if (widget.editable)
                  for (final cell in cells)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: cell,
                    ),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: widget.current || pending
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.current)
                    Text(
                      [
                        'Objetivo · ${workoutTargetLabel(set)}',
                        if (set.targetLoadKg case final load?)
                          '${workoutNumber(load)} kg',
                        if (set.usesRir && set.targetRir != null)
                          'RIR ${workoutNumber(set.targetRir!)}',
                        if (set.targetRpe case final effort?)
                          'RPE ${workoutNumber(effort)}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En iOS las casillas en reposo se dibujan como texto para que el valor
/// siga visible al desplazar o plegar las filas. Se monta el editor al tocar.
class _InlineRecordTapToEdit extends StatefulWidget {
  const _InlineRecordTapToEdit({
    super.key,
    required this.controller,
    required this.enabled,
    required this.label,
    required this.alignment,
    required this.style,
    required this.decoration,
    required this.buildEditor,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final TextAlign alignment;
  final TextStyle? style;
  final InputDecoration decoration;
  final Widget Function(FocusNode) buildEditor;

  @override
  State<_InlineRecordTapToEdit> createState() => _InlineRecordTapToEditState();
}

class _InlineRecordTapToEditState extends State<_InlineRecordTapToEdit> {
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_editing && !_focus.hasFocus) setState(() => _editing = false);
  }

  void _startEditing() {
    if (!widget.enabled || _editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) return widget.buildEditor(_focus);
    final value = widget.controller.text;
    return Semantics(
      label: widget.label,
      value: value.isEmpty ? 'Sin registrar' : value,
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? _startEditing : null,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.enabled ? _startEditing : null,
        child: InputDecorator(
          decoration: widget.decoration.copyWith(enabled: widget.enabled),
          baseStyle: widget.style,
          textAlign: widget.alignment,
          textAlignVertical: TextAlignVertical.center,
          isEmpty: value.isEmpty,
          child: Text(
            value,
            style: widget.style,
            textAlign: widget.alignment,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
