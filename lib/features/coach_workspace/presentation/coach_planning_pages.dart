import 'package:workout_core/workout_template.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import '../../../core/navigation/workflow_exit_guard.dart';
import '../domain/coach_planning_repository.dart';
import 'coach_mobile_style.dart';
import 'coach_pages.dart';
import 'coach_workspace_scope.dart';

String coachPlanningRoute(
  String path, {
  String? client,
  DateTime? day,
  String? session,
}) => Uri(
  path: '/coach/$path',
  queryParameters: {
    'client': ?client,
    if (day != null) 'day': appointmentDay(day),
    'session': ?session,
  },
).toString();

Future<DateTime?> coachPickDay(BuildContext context, DateTime day) =>
    showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );

Future<bool> coachConfirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    ) ==
    true;

/// Un intento incierto conserva identidad y campos. Cambiar de espacio conserva
/// la página; salir de ella exige confirmar y no provoca un segundo envío.
mixin CoachWriteState<T extends StatefulWidget> on State<T> {
  bool busy = false, done = false, dirty = false;
  String? operation, error;
  bool get frozen => operation != null;
  Future<void> write(Future<void> Function(String id) save) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      operation ??= trainerMessageOperationId();
    });
    try {
      await save(operation!);
      if (!mounted) return;
      setState(() {
        done = true;
        busy = false;
      });
      context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo confirmar. Reintenta con los mismos datos. ${trainerError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget form(
    String title,
    List<Widget> children, {
    required VoidCallback? save,
    String label = 'Guardar',
  }) => WorkflowDraftGuard(
    hasUnsavedChanges: () => !done && (dirty || frozen),
    isBusy: () => busy,
    message: frozen
        ? 'El envío no está confirmado. Puedes volver y reintentar sin duplicarlo. Si sales, revisa la agenda antes de crear otro.'
        : 'Los cambios de esta pantalla todavía no están guardados.',
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...children,
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!),
            ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(frozen ? 'Reintentar' : label),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class CoachLibraryPage extends StatelessWidget {
  const CoachLibraryPage({super.key, this.pick = false});
  final bool pick;
  @override
  Widget build(BuildContext context) {
    final repo = CoachWorkspaceScope.of(context).planning!;
    return CoachPagedList<CoachLibrarySession>(
      title: 'Mis sesiones',
      pageSize: 50,
      load: (before) => repo.sessions(before: before),
      filter: (s, q) => s.name.toLowerCase().contains(q),
      searchLabel: 'Buscar entre las sesiones cargadas',
      empty: 'Crea tus sesiones desde Trainer web. Después podrás asignarlas aquí.',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.fitness_center),
          label: const Text('Consultar ejercicios y demostraciones'),
          onPressed: () => context.push('/coach/exercises'),
        ),
      ),
      row: (context, s) => CoachNavigationCard(
        title: s.name,
        subtitle:
            '${s.isRunning ? 'Carrera' : 'Fuerza'} · Versión ${s.version}',
        icon: s.isRunning ? Icons.directions_run : Icons.fitness_center,
        onTap: () async {
          final accepted = await context.push<bool>(
            '/coach/library/${Uri.encodeComponent(s.id)}${pick ? '?pick=1' : ''}',
          );
          if (pick && accepted == true && context.mounted) {
            // onExit se resuelve antes de que go_router retire el match anterior.
            // Esperar al siguiente frame evita devolver el DTO a la vista previa.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted &&
                  GoRouter.of(context).state.uri.path == '/coach/library') {
                context.pop(s);
              }
            });
          }
        },
      ),
    );
  }
}

class CoachSessionPreviewPage extends StatelessWidget {
  const CoachSessionPreviewPage({
    super.key,
    required this.id,
    this.pick = false,
  });
  final String id;
  final bool pick;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista previa')),
    body: CoachLoad(
      load: () => CoachWorkspaceScope.of(context).planning!.template(id),
      builder: (context, template, refresh) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.event_available),
            label: Text(pick ? 'Usar esta sesión' : 'Asignar sesión'),
            onPressed: () async {
              if (pick) {
                context.pop(true);
                return;
              }
              final changed = await context.push<bool>(
                coachPlanningRoute('assign', session: id),
              );
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sesión asignada. Ya aparece en la agenda.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          WorkoutTemplateContent(template: template),
        ],
      ),
    ),
  );
}

class CoachClientPickerPage extends StatelessWidget {
  const CoachClientPickerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = CoachWorkspaceScope.of(context);
    return CoachPagedList<TrainerClient>(
      title: 'Elegir alumno',
      pageSize: 50,
      load: (before) => scope.controller.repository.clients(before: before),
      filter: (c, q) => c.name.toLowerCase().contains(q),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.person_outline),
          label: const Text('Para mí · no ocupa plaza'),
          onPressed: () async {
            try {
              final person = await scope.planning!.self();
              if (context.mounted) context.pop(person);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(trainerError(e))));
              }
            }
          },
        ),
      ),
      row: (context, c) => CoachNavigationCard(
        title: c.name,
        subtitle: 'Servicio activo',
        icon: Icons.person_outline,
        onTap: c.active ? () => context.pop(c) : null,
      ),
    );
  }
}

class CoachAssignPage extends StatefulWidget {
  const CoachAssignPage({super.key, this.clientId, this.sessionId, this.day});
  final String? clientId, sessionId;
  final DateTime? day;
  @override
  State<CoachAssignPage> createState() => _CoachAssignPageState();
}

class _CoachAssignPageState extends State<CoachAssignPage>
    with CoachWriteState<CoachAssignPage> {
  TrainerClient? _client;
  CoachLibrarySession? _session;
  late DateTime _day = DateUtils.dateOnly(widget.day ?? DateTime.now());
  final _note = TextEditingController();
  bool _initialized = false, _loading = true, _initialError = false;
  List<Map<String, dynamic>>? _schedule;
  int _generation = 0;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _init();
    }
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _initialError = false;
      error = null;
    });
    final scope = CoachWorkspaceScope.of(context);
    try {
      final person = widget.clientId == null
          ? null
          : (await scope.controller.repository.client(widget.clientId!)).client;
      if (!mounted) return;
      setState(() => _client = person);
      final template = widget.sessionId == null
          ? null
          : await scope.planning!.template(widget.sessionId!);
      if (!mounted) return;
      setState(() {
        _client = person;
        if (template != null) {
          _session = CoachLibrarySession(
            id: template.id,
            name: template.name,
            version: template.version,
            isRunning: template.blocks.any(
              (b) => b.items.any(
                (i) =>
                    i.exerciseId == runningExerciseId ||
                    i.sets.any((s) => s.runningStep != null),
              ),
            ),
            createdAt: DateTime.now(),
          );
        }
        _loading = false;
      });
      await _preview();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = trainerError(e);
          _initialError = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _preview() async {
    final generation = ++_generation, person = _client;
    setState(() => _schedule = null);
    if (person == null) return;
    try {
      final v = await CoachWorkspaceScope.of(context).planning!
          .schedule(person.personId, _day);
      if (mounted && generation == _generation) {
        setState(() {
          _schedule = v;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => error = trainerError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => form(
    'Asignar sesión',
    [
      if (_loading) const LinearProgressIndicator(),
      if (_initialError && !frozen)
        TextButton(
          onPressed: _init,
          child: const Text('Reintentar carga inicial'),
        ),
      CoachNavigationCard(
        title: _client?.name ?? 'Elegir alumno',
        subtitle: _client?.isSelf == true
            ? 'Para mí · sin ocupar plaza'
            : 'Destinatario',
        icon: Icons.person_outline,
        onTap: frozen || _loading
            ? null
            : () async {
                final v = await context.push<TrainerClient>(
                  '/coach/choose-client',
                );
                if (v != null && mounted) {
                  setState(() {
                    _client = v;
                    dirty = true;
                    error = null;
                  });
                  _preview();
                }
              },
      ),
      CoachNavigationCard(
        title: _session?.name ?? 'Elegir sesión',
        subtitle: _session == null
            ? 'Tu biblioteca privada'
            : 'Versión ${_session!.version}',
        icon: _session?.isRunning == true
            ? Icons.directions_run
            : Icons.fitness_center,
        onTap: frozen || _loading
            ? null
            : () async {
                final v = await context.push<CoachLibrarySession>(
                  '/coach/library?pick=1',
                );
                if (v != null && mounted) {
                  setState(() {
                    _session = v;
                    dirty = true;
                    error = null;
                  });
                }
              },
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today),
        label: Text(coachDate(_day)),
        onPressed: frozen
            ? null
            : () async {
                final v = await coachPickDay(context, _day);
                if (v != null && mounted) {
                  setState(() {
                    _day = v;
                    dirty = true;
                    error = null;
                  });
                  _preview();
                }
              },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        enabled: !frozen,
        maxLength: 500,
        maxLines: 3,
        onChanged: (_) => dirty = true,
        decoration: const InputDecoration(
          labelText: 'Indicaciones para esta sesión (opcional)',
        ),
      ),
      const Text(
        'Se añade a la planificación del alumno. No sustituye automáticamente otras sesiones.',
      ),
      if (_client != null) ...[
        const SizedBox(height: 12),
        if (_schedule == null)
          TextButton(
            onPressed: _preview,
            child: const Text('Comprobar planificación de ese día'),
          )
        else
          CoachScheduleNotice(value: _schedule!),
      ],
    ],
    label: 'Confirmar asignación',
    save:
        _loading ||
            _client?.active != true ||
            _session == null ||
            _schedule == null
        ? null
        : () => write(
            (id) => CoachWorkspaceScope.of(context).planning!.assign(
              operationId: id,
              relationId: _client!.activeRelationId!,
              templateId: _session!.id,
              date: _day,
              note: _note.text,
            ),
          ),
  );
}

class CoachScheduleNotice extends StatelessWidget {
  const CoachScheduleNotice({super.key, required this.value});
  final List<Map<String, dynamic>> value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          value.isEmpty
              ? 'No se detectan coincidencias con otras planificaciones.'
              : 'Coincide con otra planificación del alumno. Coordina la carga antes de asignar.',
        ),
      ),
    );
  }
}

class CoachNotesPage extends StatelessWidget {
  const CoachNotesPage({super.key, required this.clientId});
  final String clientId;
  @override
  Widget build(BuildContext context) => CoachLoad(
    load: () => CoachWorkspaceScope.of(context).planning!.notes(clientId),
    builder: (_, notes, refresh) => _CoachNotesForm(
      key: ValueKey(notes.revision),
      clientId: clientId,
      notes: notes,
    ),
  );
}

class _CoachNotesForm extends StatefulWidget {
  const _CoachNotesForm({
    super.key,
    required this.clientId,
    required this.notes,
  });
  final String clientId;
  final CoachPrivateNotes notes;
  @override
  State<_CoachNotesForm> createState() => _CoachNotesFormState();
}

class _CoachNotesFormState extends State<_CoachNotesForm>
    with CoachWriteState<_CoachNotesForm> {
  late final _notes = TextEditingController(text: widget.notes.notes),
      _goal = TextEditingController(text: widget.notes.goal);
  @override
  void dispose() {
    _notes.dispose();
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => form(
    'Notas privadas',
    [
      const Text(
        'Solo para ti. El alumno no las ve. El objetivo interno no cambia sus pruebas ni sus marcas.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _goal,
        enabled: widget.notes.canEdit && !frozen,
        maxLength: 500,
        maxLines: 2,
        onChanged: (_) => dirty = true,
        decoration: const InputDecoration(labelText: 'Objetivo interno'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        enabled: widget.notes.canEdit && !frozen,
        maxLength: 2000,
        maxLines: 7,
        onChanged: (_) => dirty = true,
        decoration: const InputDecoration(labelText: 'Notas del preparador'),
      ),
    ],
    save: widget.notes.canEdit
        ? () => write(
            (id) => CoachWorkspaceScope.of(context).planning!.saveNotes(
              id,
              widget.clientId,
              widget.notes,
              _notes.text,
              _goal.text,
            ),
          )
        : null,
  );
}
