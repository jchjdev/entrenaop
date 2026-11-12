import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import 'trainer_program_repository.dart';

class TrainerProgramUpdatesDialog extends StatefulWidget {
  const TrainerProgramUpdatesDialog({
    super.key,
    required this.repository,
    required this.programId,
    required this.openSession,
  });

  final TrainerProgramUpdates repository;
  final String programId;
  final Future<void> Function(String) openSession;

  @override
  State<TrainerProgramUpdatesDialog> createState() =>
      _TrainerProgramUpdatesDialogState();
}

class _TrainerProgramUpdatesDialogState
    extends State<TrainerProgramUpdatesDialog> {
  late var _preview = widget.repository.previewUpdates(widget.programId);
  final _selected = <String>{};
  ({String id, List<TrainerProgramUpdate> sessions})? _pending;
  ({int updated, int skipped})? _receipt;
  bool _saving = false;
  String? _error;

  void _select(Iterable<TrainerProgramUpdate> rows, bool checked) {
    final ids = rows.where((row) => row.eligible).map((row) => row.id);
    setState(() => checked ? _selected.addAll(ids) : _selected.removeAll(ids));
  }

  Future<void> _apply(List<TrainerProgramUpdate> rows) async {
    final pending = _pending ??= (
      id: newGuidedWorkId(),
      sessions: rows.where((row) => _selected.contains(row.id)).toList(),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.applyUpdates(
        pending.id,
        widget.programId,
        pending.sessions,
      );
      if (mounted) setState(() => _receipt = result);
    } catch (error) {
      if (mounted) setState(() => _error = trainerError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _student(List<TrainerProgramUpdate> rows) {
    final eligible = rows.where((row) => row.eligible).length;
    final checked = rows.where((row) => _selected.contains(row.id)).length;
    return ExpansionTile(
      key: PageStorageKey(rows.first.clientId),
      leading: Checkbox(
        semanticLabel: 'Seleccionar sesiones de ${rows.first.clientName}',
        tristate: true,
        value: checked == 0
            ? false
            : checked == eligible
            ? true
            : null,
        onChanged: eligible == 0 || _pending != null
            ? null
            : (_) => _select(rows, checked != eligible),
      ),
      title: Text(rows.first.clientName),
      subtitle: Text(
        '$checked seleccionadas · $eligible disponibles · ${rows.length - eligible} omitidas',
      ),
      children: [
        for (final row in rows)
          ListTile(
            leading: row.eligible
                ? Checkbox(
                    semanticLabel: 'Seleccionar ${row.name}',
                    value: _selected.contains(row.id),
                    onChanged: _pending != null
                        ? null
                        : (checked) => _select([row], checked!),
                  )
                : const Icon(Icons.remove_circle_outline),
            title: Text(row.name),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatShortDate(row.date)} · ${switch (row.reason) {
                'eligible' => 'v${row.fromVersion} → v${row.toVersion}',
                'started' => 'Ya iniciada',
                'adapted' => 'Adaptada a mano',
                'not_pending' => 'Fuera de las pendientes',
                'unchanged' => 'Ya tiene esta versión',
                _ => 'Correspondencia sin confirmar',
              }}',
            ),
            trailing: row.eligible
                ? IconButton(
                    tooltip: 'Ver sesión actualizada',
                    onPressed: () => widget.openSession(row.templateId!),
                    icon: const Icon(Icons.visibility_outlined),
                  )
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<List<TrainerProgramUpdate>>(
            future: _preview,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <TrainerProgramUpdate>[];
              final byStudent = <String, List<TrainerProgramUpdate>>{};
              for (final row in rows) {
                byStudent.putIfAbsent(row.clientId, () => []).add(row);
              }
              final students = byStudent.values.toList();
              final result = _receipt;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Actualizar pautas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (result != null)
                    Expanded(
                      child: Text(
                        'Actualizadas · ${result.updated}\nOmitidas al confirmar · ${result.skipped}',
                      ),
                    )
                  else if (snapshot.hasError)
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _preview = widget.repository.previewUpdates(
                              widget.programId,
                            );
                          }),
                          child: const Text('Reintentar vista previa'),
                        ),
                      ),
                    )
                  else if (!snapshot.hasData)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (students.isEmpty)
                    const Expanded(
                      child: Text(
                        'Aún no hay pautas de versiones anteriores de este programa.',
                      ),
                    )
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Sesiones seleccionadas · ${_selected.length}'),
                        TextButton(
                          onPressed:
                              _pending != null ||
                                  !rows.any((row) => row.eligible)
                              ? null
                              : () => _select(rows, true),
                          child: const Text('Seleccionar a todos'),
                        ),
                        TextButton(
                          onPressed: _pending != null || _selected.isEmpty
                              ? null
                              : () => _select(rows, false),
                          child: const Text('Quitar selección'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (_, index) => _student(students[index]),
                      ),
                    ),
                  ],
                  if (_saving) const LinearProgressIndicator(),
                  if (_error case final error?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error),
                    ),
                  OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(result != null ? 'Cerrar' : 'Volver'),
                      ),
                      if (result == null)
                        FilledButton(
                          onPressed: _saving || _selected.isEmpty
                              ? null
                              : () => _apply(rows),
                          child: Text(
                            _pending == null
                                ? 'Confirmar actualización'
                                : 'Reintentar actualización',
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
