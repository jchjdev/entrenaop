import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';

class TrainerAssignmentVisibilityFilter extends StatelessWidget {
  const TrainerAssignmentVisibilityFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final TrainerAssignmentVisibility value;
  final ValueChanged<TrainerAssignmentVisibility>? onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in TrainerAssignmentVisibility.values)
        ChoiceChip(
          key: ValueKey('assignment-filter-${option.name}'),
          label: Text(option.label),
          selected: value == option,
          onSelected: onChanged == null ? null : (_) => onChanged!(option),
        ),
    ],
  );
}

/// Una sola confirmación y contrato para ficha, agenda y listado del alumno.
class TrainerAssignmentLifecycleActions extends StatefulWidget {
  const TrainerAssignmentLifecycleActions({
    super.key,
    required this.assignment,
    required this.repository,
    required this.onChanged,
    this.enabled = true,
    this.onBusyChanged,
  });
  final TrainerAssignment assignment;
  final TrainerWorkoutRepository repository;
  final Future<void> Function() onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool enabled;
  @override
  State<TrainerAssignmentLifecycleActions> createState() =>
      _TrainerAssignmentLifecycleActionsState();
}

class _TrainerAssignmentLifecycleActionsState
    extends State<TrainerAssignmentLifecycleActions> {
  bool _busy = false;
  String? _error;
  final _operations = <TrainerAssignmentLifecycleAction, String>{};

  Future<void> _change(TrainerAssignmentLifecycleAction action) async {
    if (_busy || !widget.enabled) return;
    final item = widget.assignment, repository = widget.repository;
    if (action == TrainerAssignmentLifecycleAction.delete) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Borrar sesión definitivamente'),
          content: Text(
            'Se borrará «${item.name}» del calendario del alumno. No se puede deshacer. La plantilla de tu biblioteca se conserva. El servidor impedirá el borrado si tiene resultados, vínculos con Garmin u otras referencias.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Conservar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Borrar definitivamente'),
            ),
          ],
        ),
      );
      if (yes != true ||
          !mounted ||
          item != widget.assignment ||
          repository != widget.repository ||
          !widget.enabled) {
        return;
      }
    }
    final changed = widget.onChanged, busyChanged = widget.onBusyChanged;
    setState(() {
      _busy = true;
      _error = null;
    });
    busyChanged?.call(true);
    try {
      // Un fallo de red conserva la identidad del intento, también para DELETE.
      await repository.changeLifecycle(
        operationId: _operations.putIfAbsent(action, trainerOperationId),
        assignment: item,
        action: action,
      );
      if (!mounted ||
          item != widget.assignment ||
          repository != widget.repository) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      await changed();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            TrainerAssignmentLifecycleAction.archive =>
              'Sesión archivada. Puedes verla en «Archivadas».',
            TrainerAssignmentLifecycleAction.restore =>
              'Sesión restaurada en la vista habitual. Sigue retirada.',
            TrainerAssignmentLifecycleAction.delete =>
              'Sesión eliminada. Tu plantilla se conserva.',
          }),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = trainerError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
      busyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.assignment;
    if (item.status != 'cancelled') return const SizedBox.shrink();
    final enabled = widget.enabled && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.archived)
          const Text(
            'Archivada en tu portal. El alumno conserva la marca de retirada.',
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: !enabled
                  ? null
                  : () => _change(
                      item.archived
                          ? TrainerAssignmentLifecycleAction.restore
                          : TrainerAssignmentLifecycleAction.archive,
                    ),
              icon: Icon(
                item.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(
                item.archived ? 'Restaurar en calendario' : 'Archivar sesión',
              ),
            ),
            TextButton.icon(
              onPressed: enabled && item.deletionExplanation == null
                  ? () => _change(TrainerAssignmentLifecycleAction.delete)
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar definitivamente'),
            ),
          ],
        ),
        if (item.deletionExplanation case final reason?) Text(reason),
        if (_error case final error?)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}
