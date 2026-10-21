import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/guided_program_editor_adapter.dart';
import 'package:workout_editor_ui/program_session_catalog.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_template_content.dart';
import 'package:workout_core/workout_template.dart';

import 'trainer_program_repository.dart';
import 'trainer_workout_repository.dart';

class TrainerProgramDetailPage extends StatefulWidget {
  const TrainerProgramDetailPage({
    super.key,
    required this.repository,
    required this.workouts,
    required this.programId,
  });
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final String programId;
  @override
  State<TrainerProgramDetailPage> createState() =>
      _TrainerProgramDetailPageState();
}

class _TrainerProgramDetailPageState extends State<TrainerProgramDetailPage> {
  late Future<GuidedProgram> _program = widget.repository.program(
    widget.programId,
  );
  Future<void> _preview(String id) async {
    try {
      final template = await widget.workouts.template(id);
      if (!mounted) return;
      if (template == null) throw StateError('Sesión no disponible');
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                WorkoutTemplateContent(template: template),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver al programa'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trainerError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Programa privado')),
    body: FutureBuilder<GuidedProgram>(
      future: _program,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = snapshot.data;
        if (snapshot.hasError || p == null) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _program = widget.repository.program(widget.programId),
              ),
              child: const Text('No se pudo cargar el programa. Reintentar'),
            ),
          );
        }
        return _programFrame([
          Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('${p.modeLabel} · v${p.version} · Privado'),
          if (p.description.isNotEmpty) Text(p.description),
          if (p.audience.isNotEmpty) Text('Destinatarios: ${p.audience}'),
          if (p.equipment.isNotEmpty) Text('Material: ${p.equipment}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: () async {
                  final result = await context.push('/programs/${p.id}/revise');
                  if (result == true && context.mounted) context.pop(true);
                },
                child: const Text('Crear nueva versión'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/clients'),
                child: const Text('Elegir alumno para asignar'),
              ),
            ],
          ),
          for (final phase in p.phases)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      phase.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (phase.durationWeeks != null)
                      Text('${phase.durationWeeks} semanas orientativas'),
                    if (phase.instructions.isNotEmpty) Text(phase.instructions),
                    for (final session in phase.sessions)
                      ListTile(
                        title: Text(session.name),
                        trailing: const Icon(Icons.visibility_outlined),
                        onTap: () => _preview(session.templateId),
                      ),
                  ],
                ),
              ),
            ),
        ]);
      },
    ),
  );
}

class TrainerProgramLibraryPage extends StatefulWidget {
  const TrainerProgramLibraryPage({
    super.key,
    required this.repository,
    required this.access,
  });
  final TrainerProgramRepository repository;
  final TrainerRepository access;
  @override
  State<TrainerProgramLibraryPage> createState() =>
      _TrainerProgramLibraryPageState();
}

class _TrainerProgramLibraryPageState extends State<TrainerProgramLibraryPage> {
  List<TrainerProgram> _items = [];
  bool _busy = true, _more = false, _canCreate = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.access.access();
      final rows = await widget.repository.programs(
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
          _canCreate = access.effective;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis programas privados'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _programFrame([
      const Text(
        'Organiza sesiones por rutinas o fases y reutiliza cada programa con tus alumnos. Cada pauta conserva la versión asignada.',
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy || !_canCreate
            ? null
            : () async {
                await context.push('/programs/new');
                if (mounted) await _load();
              },
        icon: const Icon(Icons.add),
        label: const Text('Crear programa privado'),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) ...[
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('Reintentar')),
      ],
      if (!_busy && _error == null && _items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todavía no has creado programas privados.'),
        ),
      for (final row in _items)
        Card(
          child: ListTile(
            title: Text(row.program.name),
            subtitle: Text(
              '${row.program.modeLabel} · ${row.program.sessionCount} sesiones · v${row.program.version}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await context.push('/programs/${row.program.id}');
              if (mounted) await _load();
            },
          ),
        ),
      if (_more)
        OutlinedButton(
          onPressed: _busy ? null : () => _load(more: true),
          child: const Text('Cargar más programas'),
        ),
    ]),
  );
}

class TrainerProgramEditorPage extends StatefulWidget {
  const TrainerProgramEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    this.programId,
  });
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final String? programId;
  @override
  State<TrainerProgramEditorPage> createState() =>
      _TrainerProgramEditorPageState();
}

class _TrainerProgramEditorPageState extends State<TrainerProgramEditorPage> {
  late Future<GuidedProgram?> _initial = _load();
  TrainerProgramComposition? _composition;
  Future<GuidedProgram?> _load() async {
    final original = widget.programId == null
        ? null
        : await widget.repository.program(widget.programId!);
    _composition = TrainerProgramComposition(
      widget.repository,
      widget.workouts,
      original: original,
    );
    return original;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GuidedProgram?>(
    future: _initial,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Programa privado')),
          body: Center(
            child: TextButton(
              onPressed: () => setState(() => _initial = _load()),
              child: const Text('No se pudo cargar el programa. Reintentar'),
            ),
          ),
        );
      }
      return GuidedProgramEditorPage(
        repository: _composition!,
        workouts: _composition!,
        original: snapshot.data,
        adapter: _TrainerProgramAdapter(widget.workouts),
      );
    },
  );
}

class _TrainerProgramAdapter extends GuidedProgramEditorAdapter {
  const _TrainerProgramAdapter(this.workouts);
  final TrainerWorkoutRepository workouts;
  @override
  bool get professional => true;
  @override
  Future<void> openSession(
    BuildContext context, {
    required String programName,
    String? sessionId,
    required bool duplicate,
    required Future<void> Function(String) onSaved,
  }) async {
    var copy = duplicate;
    if (sessionId != null && !copy) {
      TrainerWorkout? cursor;
      var current = false;
      do {
        final rows = await workouts.workouts(before: cursor);
        current = rows.any((s) => s.id == sessionId);
        if (current || rows.length < 50) break;
        cursor = rows.last;
      } while (true);
      // Revisar una referencia histórica parte de una copia; nunca sustituye
      // retrospectivamente la receta fijada en programas o pautas anteriores.
      copy = !current;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PrivateSessionWorkspace(
        repository: workouts,
        sessionId: sessionId,
        duplicate: copy,
        onSaved: onSaved,
      ),
    );
  }

  @override
  void finish(BuildContext context, String id, bool review) {
    context.canPop() ? context.pop(true) : context.go('/programs');
  }

  @override
  Future<void> openLibrary(BuildContext context) async {
    await context.push('/workouts');
  }

  @override
  void openPrograms(BuildContext context) {
    context.go('/programs');
  }

  @override
  Future<String?> createWarmup(BuildContext context) async => null;
  @override
  Future<GuidedProgramCategory?> createCategory(BuildContext context) async =>
      null;
  @override
  Future<void> manageCategories(BuildContext context) async {}
  @override
  Widget sessionStatus(ProgramSessionSummary? session) => Text(
    session == null
        ? 'Sesión no disponible'
        : 'Privada · versión fijada en este programa',
  );
  @override
  bool definitiveError(Object error) =>
      error is PostgrestException &&
      ['22023', '23503', '42501', '40001'].contains(error.code);
}

class _PrivateSessionWorkspace extends StatefulWidget {
  const _PrivateSessionWorkspace({
    required this.repository,
    required this.sessionId,
    required this.duplicate,
    required this.onSaved,
  });
  final TrainerWorkoutRepository repository;
  final String? sessionId;
  final bool duplicate;
  final Future<void> Function(String) onSaved;
  @override
  State<_PrivateSessionWorkspace> createState() =>
      _PrivateSessionWorkspaceState();
}

class _PrivateSessionWorkspaceState extends State<_PrivateSessionWorkspace> {
  final _exit = WorkflowExitController();
  final _operation = trainerOperationId();
  late final Future<WorkoutTemplate?> _initial = widget.sessionId == null
      ? Future.value(null)
      : widget.repository.template(widget.sessionId!);
  bool _canPop = false, _busy = false;
  String? _saved, _error;
  Future<void> _close({bool saved = false}) async {
    if (_busy) return;
    if (!saved && !await (_exit.onExit?.call() ?? Future.value(true))) return;
    if (!mounted) return;
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _link(String id) async {
    if (_busy) return;
    setState(() {
      _saved = id;
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSaved(id);
      if (mounted) {
        setState(() => _busy = false);
        await _close(saved: true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Sesión guardada. Falta confirmar su incorporación al programa.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(child: Text('Sesión del programa privado')),
                  IconButton(
                    onPressed: _busy ? null : () => _close(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Volver al programa',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: _busy
                    ? const Center(child: CircularProgressIndicator())
                    : _saved != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _error ?? 'Confirmar incorporación de la sesión',
                            ),
                            FilledButton(
                              onPressed: () => _link(_saved!),
                              child: const Text('Reintentar enlace'),
                            ),
                          ],
                        ),
                      )
                    : FutureBuilder<WorkoutTemplate?>(
                        future: _initial,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError ||
                              (widget.sessionId != null &&
                                  snapshot.data == null)) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No se pudo cargar la sesión. Vuelve al programa y reintenta.',
                              ),
                            );
                          }
                          final source = snapshot.data;
                          final initial = source == null
                              ? null
                              : widget.duplicate
                              ? WorkoutTemplate(
                                  id: source.id,
                                  name:
                                      '${source.name.characters.take(110)} · copia',
                                  description: source.description,
                                  estimatedDurationMinutes:
                                      source.estimatedDurationMinutes,
                                  version: 1,
                                  blocks: source.blocks,
                                )
                              : source;
                          return WorkflowExitScope(
                            controller: _exit,
                            child: WorkoutEditorPage(
                              embedded: true,
                              loadExercises: () => widget.repository.exercises(
                                retainedIds: {
                                  for (final block
                                      in initial?.blocks ?? <WorkoutBlock>[])
                                    for (final item in block.items)
                                      item.exerciseId,
                                },
                              ),
                              originalTemplate: initial,
                              onSave: (input) => widget.repository.save(
                                _operation,
                                input,
                                previousId: widget.duplicate
                                    ? null
                                    : widget.sessionId,
                              ),
                              onSaved: _link,
                              title: 'Sesión privada',
                              heading: 'Programa privado',
                              instructions: 'La sesión se guarda en tu biblioteca y después se incorpora al programa.',
                              saveLabel: 'Guardar e incorporar sesión',
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TrainerProgramAssignmentDialog extends StatefulWidget {
  const TrainerProgramAssignmentDialog({
    super.key,
    required this.repository,
    required this.relationId,
  });
  final TrainerProgramRepository repository;
  final String relationId;
  @override
  State<TrainerProgramAssignmentDialog> createState() =>
      _TrainerProgramAssignmentDialogState();
}

class _TrainerProgramAssignmentDialogState
    extends State<TrainerProgramAssignmentDialog> {
  final _note = TextEditingController();
  List<TrainerProgram> _programs = [];
  GuidedProgram? _program;
  int _phase = -1;
  final _entries = <TrainerProgramEntry>[];
  bool _busy = true, _more = false;
  String? _error, _operation;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.programs(
        before: more ? _programs.last : null,
      );
      if (mounted) {
        setState(() {
          _programs = more ? [..._programs, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose(GuidedProgram program, {int? phase}) {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _program = program;
      _phase = phase ?? (program.sessionCount > 256 ? 0 : -1);
      _entries.clear();
      for (var pi = 0; pi < program.phases.length; pi++) {
        if (_phase != -1 && pi != _phase) continue;
        for (var si = 0; si < program.phases[pi].sessions.length; si++) {
          _entries.add(
            TrainerProgramEntry(
              pi,
              si,
              DateTime(
                today.year,
                today.month,
                today.day + _entries.length * 2,
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _assign() async {
    if (_busy || _program == null || _entries.isEmpty) return;
    final dates = _entries
        .map((e) => '${e.phase}:${e.session}:${e.toJson()['date']}')
        .toSet();
    if (dates.length != _entries.length) {
      setState(
        () => _error = 'La misma sesión aparece dos veces en una fecha. Corrige esa fecha o quita la repetición antes de confirmar.',
      );
      return;
    }
    _operation ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.assign(
        id: _operation!,
        relationId: widget.relationId,
        programId: _program!.id!,
        entries: List.of(_entries),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${trainerError(e)} Reintenta la misma planificación; se conserva su identificador.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sessionName(TrainerProgramEntry e) =>
      _program!.phases[e.phase].sessions[e.session].name;
  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: !_busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Pautar programa privado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Elige el programa y revisa cada fecha. La propuesta separa las sesiones dos días; ajústala a la disponibilidad del alumno. Las fases no avanzan automáticamente.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_program == null) ...[
              for (final row in _programs)
                ListTile(
                  title: Text(row.program.name),
                  subtitle: Text(
                    'v${row.program.version} · ${row.program.sessionCount} sesiones',
                  ),
                  onTap: _busy ? null : () => _choose(row.program),
                  trailing: const Icon(Icons.chevron_right),
                ),
              if (!_busy && _programs.isEmpty && _error == null)
                const Text(
                  'Crea primero un programa en tu biblioteca privada.',
                ),
              if (_more)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Cargar más programas'),
                ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '${_program!.name} · v${_program!.version}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_program!.description.isNotEmpty) Text(_program!.description),
              const SizedBox(height: 12),
              const Text('Fases que vas a pautar'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                key: ValueKey('${_program!.id}:$_phase'),
                initialValue: _phase,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: [
                  if (_program!.sessionCount <= 256)
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Todas las fases'),
                    ),
                  for (var i = 0; i < _program!.phases.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(_program!.phases[i].name),
                    ),
                ],
                onChanged: _busy || _operation != null
                    ? null
                    : (value) {
                        if (value != null) _choose(_program!, phase: value);
                      },
              ),
              if (_program!.sessionCount > 256)
                const Text(
                  'Este programa se pauta por fases. Cada envío admite hasta 256 sesiones con fechas concretas.',
                ),
              TextButton(
                onPressed: _busy || _operation != null
                    ? null
                    : () => setState(() {
                        _program = null;
                        _entries.clear();
                      }),
                child: const Text('Elegir otro programa'),
              ),
              for (var i = 0; i < _entries.length; i++)
                Card(
                  key: ValueKey('program-date-$i'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_program!.phases[_entries[i].phase].name),
                        Text(_sessionName(_entries[i])),
                        if (_program!
                            .phases[_entries[i].phase]
                            .instructions
                            .isNotEmpty)
                          Text(
                            _program!.phases[_entries[i].phase].instructions,
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy || _operation != null
                                  ? null
                                  : () async {
                                      final old = _entries[i];
                                      final chosen = await showDatePicker(
                                        context: context,
                                        initialDate: old.date,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (chosen != null && mounted) {
                                        setState(
                                          () =>
                                              _entries[i] = TrainerProgramEntry(
                                                old.phase,
                                                old.session,
                                                chosen,
                                              ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.calendar_month),
                              label: Text(_date(_entries[i].date)),
                            ),
                            TextButton(
                              onPressed: _busy || _operation != null
                                  ? null
                                  : () => setState(() => _entries.removeAt(i)),
                              child: const Text('Quitar de esta pauta'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_entries.length < 256)
                OutlinedButton.icon(
                  onPressed: _busy || _operation != null || _entries.isEmpty
                      ? null
                      : () => setState(() {
                          final latest = _entries
                              .map((e) => e.date)
                              .reduce((a, b) => a.isAfter(b) ? a : b);
                          final earliest = _entries
                              .map((e) => e.date)
                              .reduce((a, b) => a.isBefore(b) ? a : b);
                          final span =
                              (DateTime.utc(
                                            latest.year,
                                            latest.month,
                                            latest.day,
                                          )
                                          .difference(
                                            DateTime.utc(
                                              earliest.year,
                                              earliest.month,
                                              earliest.day,
                                            ),
                                          )
                                          .inDays ~/
                                      7 +
                                  1) *
                              7;
                          final copies = [
                            for (final e in _entries)
                              TrainerProgramEntry(
                                e.phase,
                                e.session,
                                DateTime(
                                  e.date.year,
                                  e.date.month,
                                  e.date.day + span,
                                ),
                              ),
                          ];
                          _entries.addAll(copies.take(256 - _entries.length));
                        }),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Repetir la planificación después'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                enabled: !_busy && _operation == null,
                maxLength: 320,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Indicaciones para el alumno',
                ),
              ),
              const Text(
                'Se añaden a su agenda junto a su plan automático. No se sustituyen entrenamientos existentes; el alumno verá los avisos de coincidencia.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || _entries.isEmpty ? null : _assign,
                child: Text(
                  _operation == null
                      ? 'Confirmar ${_entries.length} ${_entries.length == 1 ? 'sesión' : 'sesiones'}'
                      : 'Comprobar y reintentar planificación',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (_program == null)
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Reintentar carga'),
                ),
            ],
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Volver al alumno'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _programFrame(List<Widget> children) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: ListView(padding: const EdgeInsets.all(20), children: children),
  ),
);
