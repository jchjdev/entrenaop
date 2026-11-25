import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/entities/workout_session_set_draft.dart';
import 'workout_execution_labels.dart';
import 'workout_inline_records.dart';

/// Presentación agrupada de registros. No guarda datos ni decide transiciones.
class WorkoutSessionRecords extends StatefulWidget {
  const WorkoutSessionRecords({
    super.key,
    required this.execution,
    required this.drafts,
    required this.onEdit,
    this.enabled = true,
    this.onTechnique,
    this.initialSetId,
    this.onUpdate,
    this.onConfirm,
    this.resting = false,
    this.clockSetId,
  });
  final WorkoutExecution execution;
  final Map<String, WorkoutSessionSetDraft> drafts;
  final ValueChanged<WorkoutExecutionSet> onEdit;
  final bool enabled;
  final ValueChanged<WorkoutExecutionSet>? onTechnique;
  final String? initialSetId;
  final InlineRecordUpdate? onUpdate;
  final InlineRecordConfirm? onConfirm;
  final bool resting;
  final String? clockSetId;

  @override
  State<WorkoutSessionRecords> createState() => _WorkoutSessionRecordsState();
}

class _WorkoutSessionRecordsState extends State<WorkoutSessionRecords> {
  final _initialRecordKey = GlobalKey();
  late final String? _initialSetId;
  WorkoutExecution get execution => widget.execution;
  Map<String, WorkoutSessionSetDraft> get drafts => widget.drafts;
  ValueChanged<WorkoutExecutionSet>? get onTechnique => widget.onTechnique;

  @override
  void initState() {
    super.initState();
    _initialSetId = widget.initialSetId;
    // Solo al abrir: los ticks del descanso y las confirmaciones no deben
    // mover la lista mientras el deportista consulta otra serie.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _initialRecordKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: .15);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WorkoutExecutionSet>>{};
    for (final set in execution.sets) {
      groups
          .putIfAbsent(
            set.blockFormat == WorkoutBlockFormat.amrap
                ? 'amrap:${set.blockOrder}'
                : '${set.blockOrder}:${set.itemOrder}:${set.exerciseId}',
            () => [],
          )
          .add(set);
    }
    // Montar los grupos permite localizar también una serie situada al final
    // sin estimar alturas que cambian con el texto ampliado y los desplegables.
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final entry in groups.entries)
            if (entry.value.first.blockFormat == WorkoutBlockFormat.amrap)
              _amrapBlock(entry.value)
            else
              ExpansionTile(
                key: PageStorageKey('records-${entry.key}'),
                initiallyExpanded: entry.value.any(
                  (s) =>
                      s.id == _initialSetId ||
                      s.id == execution.currentSet?.id ||
                      (drafts[s.id]?.endedAt != null &&
                          !drafts[s.id]!.confirmed),
                ),
                title: Text(
                  entry.value.first.exerciseName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${entry.value.first.blockName} · ${entry.value.length} ${entry.value.length == 1 ? 'serie' : 'series'}',
                ),
                children: [_groupRows(entry.value)],
              ),
        ],
      ),
    );
  }

  Widget _groupRows(List<WorkoutExecutionSet> sets) {
    final update = widget.onUpdate;
    final confirm = widget.onConfirm;
    final fields = WorkoutInlineField.forSet(sets.first);
    if (update == null ||
        confirm == null ||
        fields == null ||
        sets.any(
          (set) => !listEquals(fields, WorkoutInlineField.forSet(set)),
        )) {
      return Column(children: [for (final set in sets) _row(set)]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth >= 54 + 62 * fields.length &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          return Column(
            children: [
              if (compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48, child: Text('Serie')),
                      for (final field in fields)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              field.label,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final set in sets)
                _inlineRow(set, fields, compact, update, confirm),
            ],
          );
        },
      ),
    );
  }

  Widget _inlineRow(
    WorkoutExecutionSet set,
    List<WorkoutInlineField> fields,
    bool compact,
    InlineRecordUpdate update,
    InlineRecordConfirm confirm,
  ) {
    final current = set.id == execution.currentSet?.id;
    final waitingStatus = !current
        ? null
        : widget.resting
        ? 'Después del descanso'
        : set.id == widget.clockSetId
        ? 'Cronómetro en el entreno'
        : null;
    return KeyedSubtree(
      key: set.id == _initialSetId ? _initialRecordKey : ValueKey(set.id),
      child: WorkoutInlineRecordRow(
        key: ValueKey((set.id, waitingStatus)),
        set: set,
        fields: fields,
        draft: drafts[set.id],
        current: current,
        editable:
            set.status == WorkoutSetStatus.completed ||
            (current && waitingStatus == null),
        enabled: widget.enabled,
        compact: compact,
        waitingStatus: waitingStatus,
        onUpdate: update,
        onConfirm: confirm,
      ),
    );
  }

  Widget _amrapBlock(List<WorkoutExecutionSet> sets) {
    final first = sets.first;
    final result = execution.amrapResultFor(first.blockOrder);
    return ExpansionTile(
      key: PageStorageKey('records-amrap-${first.blockOrder}'),
      initiallyExpanded: result == null,
      title: Text(
        '${first.blockName} · AMRAP',
        key: sets.any((s) => s.id == _initialSetId) ? _initialRecordKey : null,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        result == null
            ? '${sets.length} ejercicios por vuelta · resultado al terminar'
            : workoutAmrapResultLabel(result, sets),
      ),
      children: [
        for (final set in sets)
          ListTile(
            title: Text(set.exerciseName),
            subtitle: Text('${set.targetReps} repeticiones por vuelta'),
            trailing: onTechnique == null
                ? null
                : const Icon(Icons.info_outline_rounded),
            onTap: onTechnique == null ? null : () => onTechnique!(set),
          ),
      ],
    );
  }

  Widget _row(WorkoutExecutionSet set) {
    final draft = drafts[set.id];
    final pending = draft?.endedAt != null && !draft!.confirmed;
    final completed = set.status == WorkoutSetStatus.completed;
    final editable = completed;
    final target = [
      workoutTargetLabel(set),
      if (set.targetLoadKg case final load?) '${workoutNumber(load)} kg',
    ].join(' · ');
    final status = pending
        ? 'Datos por confirmar'
        : completed
        ? (draft?.needsCorrection == true
              ? 'Retoques por sincronizar al cerrar'
              : 'Registrada')
        : set.status == WorkoutSetStatus.skipped
        ? 'Omitida'
        : 'Por realizar';
    return ListTile(
      key: set.id == _initialSetId ? _initialRecordKey : null,
      leading: CircleAvatar(
        radius: 16,
        child: Icon(
          set.status == WorkoutSetStatus.skipped
              ? Icons.skip_next_rounded
              : pending
              ? Icons.edit_note_rounded
              : completed
              ? Icons.check_rounded
              : Icons.circle_outlined,
          size: 18,
        ),
      ),
      title: Text(workoutPositionLabel(set)),
      subtitle: Text(
        'Objetivo · $target\n$status${completed && !pending ? '\n${workoutResultLabel(set)}' : ''}',
      ),
      trailing: editable ? const Icon(Icons.edit_outlined) : null,
      onTap: widget.enabled && editable ? () => widget.onEdit(set) : null,
    );
  }
}
