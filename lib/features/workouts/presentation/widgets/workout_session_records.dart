import 'package:flutter/material.dart';

import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/entities/workout_session_set_draft.dart';
import 'workout_execution_labels.dart';

/// Presentación agrupada de registros. No guarda datos ni decide transiciones.
class WorkoutSessionRecords extends StatelessWidget {
  const WorkoutSessionRecords({
    super.key,
    required this.execution,
    required this.drafts,
    required this.onEdit,
    this.enabled = true,
  });
  final WorkoutExecution execution;
  final Map<String, WorkoutSessionSetDraft> drafts;
  final ValueChanged<WorkoutExecutionSet> onEdit;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WorkoutExecutionSet>>{};
    for (final set in execution.sets) {
      groups
          .putIfAbsent('${set.blockOrder}:${set.exerciseId}', () => [])
          .add(set);
    }
    return ListView(
      children: [
        for (final entry in groups.entries)
          ExpansionTile(
            key: PageStorageKey('records-${entry.key}'),
            initiallyExpanded: entry.value.any(
              (s) =>
                  s.id == execution.currentSet?.id ||
                  (drafts[s.id]?.endedAt != null && !drafts[s.id]!.confirmed),
            ),
            title: Text(
              entry.value.first.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${entry.value.first.blockName} · ${entry.value.length} ${entry.value.length == 1 ? 'serie' : 'series'}',
            ),
            children: [for (final set in entry.value) _row(set)],
          ),
      ],
    );
  }

  Widget _row(WorkoutExecutionSet set) {
    final draft = drafts[set.id];
    final pending = draft?.endedAt != null && !draft!.confirmed;
    final completed = set.status == WorkoutSetStatus.completed;
    final amrap = set.blockFormat == WorkoutBlockFormat.amrap;
    final editable = completed && !amrap;
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
        'Objetivo · ${workoutTargetLabel(set)}\n$status${completed && !pending ? '\n${amrap ? '${execution.amrapResultFor(set.blockOrder)?.completedRounds ?? 0} vueltas en el bloque' : workoutResultLabel(set)}' : ''}',
      ),
      trailing: editable ? const Icon(Icons.edit_outlined) : null,
      onTap: enabled && editable ? () => onEdit(set) : null,
    );
  }
}
