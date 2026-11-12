import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/student_assigned_programs.dart';

class StudentAssignedProgramsPage extends StatefulWidget {
  const StudentAssignedProgramsPage({
    super.key,
    required this.repository,
    this.deliveryId,
  });

  final StudentAssignedProgramsRepository repository;
  final String? deliveryId;

  @override
  State<StudentAssignedProgramsPage> createState() =>
      _StudentAssignedProgramsPageState();
}

class _StudentAssignedProgramsPageState
    extends State<StudentAssignedProgramsPage> {
  var _programs = <StudentAssignedProgram>[];
  StudentAssignedProgram? _program;
  bool _busy = false, _failed = false, _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (widget.deliveryId case final id?) {
        final program = await widget.repository.get(id);
        if (!mounted) return;
        setState(() => _program = program);
      } else {
        final page = await widget.repository.list(
          before: more ? _programs.last.cursor : null,
        );
        if (!mounted) return;
        setState(() {
          _programs = more ? [..._programs, ...page.items] : page.items;
          _hasMore = page.hasMore;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  Widget _progress(int completed, int total) => Text(
    '$completed de $total ${total == 1 ? 'sesión completada' : 'sesiones completadas'}',
  );

  Widget _session(StudentAssignedSession session) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(session.name),
    subtitle: Text(
      '${MaterialLocalizations.of(context).formatShortDate(session.date)} · '
      '${switch (session.status) {
        'completed' => 'Completada',
        'in_progress' => 'En curso',
        'skipped' => 'Omitida',
        'abandoned' => 'Abandonada',
        _ => 'Pendiente',
      }}',
    ),
    leading: Icon(
      session.status == 'completed'
          ? Icons.check_circle_outline
          : Icons.event_outlined,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _open(
      '/plan/week/session/${Uri.encodeComponent(session.id)}'
      '?date=${DateFormat('yyyy-MM-dd').format(session.date)}',
    ),
  );

  List<Widget> _detail(StudentAssignedProgram program) => [
    Text(program.name, style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 4),
    Text(program.trainerName),
    if (program.description case final description?
        when description.trim().isNotEmpty) ...[
      const SizedBox(height: 12),
      Text(description),
    ],
    if (program.note case final note? when note.trim().isNotEmpty) ...[
      const SizedBox(height: 12),
      Text(note),
    ],
    const SizedBox(height: 16),
    _progress(program.completed, program.total),
    const SizedBox(height: 8),
    LinearProgressIndicator(
      value: program.total == 0 ? 0 : program.completed / program.total,
    ),
    const SizedBox(height: 16),
    for (final phase in program.phases)
      Card(
        child: ExpansionTile(
          initiallyExpanded: program.phases.length == 1,
          title: Text(phase.name),
          subtitle: _progress(phase.completed, phase.sessions.length),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (phase.instructions case final instructions?
                when instructions.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(instructions),
              ),
            for (final session in phase.sessions) _session(session),
          ],
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.deliveryId == null ? 'Programas pautados' : 'Programa pautado',
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar programas',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_failed) ...[
                const Text(
                  'No se han podido consultar los programas pautados.',
                ),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
              if (widget.deliveryId != null) ...[
                if (_program case final program?)
                  ..._detail(program)
                else if (!_busy && !_failed)
                  const Text('Este programa ya no está disponible.'),
              ] else ...[
                if (_programs.isEmpty && !_busy && !_failed)
                  const Text('Todavía no tienes programas pautados.'),
                for (final program in _programs)
                  Card(
                    child: ListTile(
                      title: Text(program.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${program.trainerName} · ${MaterialLocalizations.of(context).formatShortDate(program.createdAt.toLocal())}',
                          ),
                          _progress(program.completed, program.total),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        '/my-trainer/programs/${Uri.encodeComponent(program.id)}',
                      ),
                    ),
                  ),
                if (_hasMore)
                  TextButton(
                    onPressed: _busy ? null : () => _load(more: true),
                    child: const Text('Ver más programas'),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
