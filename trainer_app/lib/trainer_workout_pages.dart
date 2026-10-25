import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_template_content.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_workout_repository.dart';
import 'trainer_program_repository.dart';
import 'trainer_program_pages.dart';

class TrainerWorkoutLibraryPage extends StatefulWidget {
  const TrainerWorkoutLibraryPage({
    super.key,
    required this.repository,
    required this.accessRepository,
    this.workRepository,
  });
  final TrainerWorkoutRepository repository;
  final TrainerRepository accessRepository;
  final WorkoutEditorWorkRepository? workRepository;
  @override
  State<TrainerWorkoutLibraryPage> createState() =>
      _TrainerWorkoutLibraryPageState();
}

class _TrainerWorkoutLibraryPageState extends State<TrainerWorkoutLibraryPage> {
  String _query = '';
  List<TrainerWorkout> _items = [];
  List<WorkoutEditorWork> _works = [];
  bool _busy = true, _more = false, _canCreate = false;
  String? _error;
  String? _workError, _discardError;
  bool _discardBusy = false;
  WorkoutEditorWork? _discardAttempt;
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
      final access = await widget.accessRepository.access();
      final rows = await widget.repository.workouts(
        before: more ? _items.last : null,
      );
      if (!mounted) return;
      setState(() {
        _items = more ? [..._items, ...rows] : rows;
        _more = rows.length == 50;
        _canCreate = access.effective;
      });
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      // La recuperación propia sigue disponible aunque falle el catálogo o
      // se haya deshabilitado el acceso profesional a nuevas escrituras.
      if (!more && widget.workRepository != null) {
        try {
          final works = await widget.workRepository!.list();
          if (mounted) {
            setState(() {
              _works = works;
              _workError = null;
            });
          }
        } catch (error) {
          if (mounted) setState(() => _workError = trainerError(error));
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard(WorkoutEditorWork work, {bool retry = false}) async {
    final repository = widget.workRepository;
    if (_busy || _discardBusy || !_canCreate || repository == null) return;
    if (!retry) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar trabajo incompleto'),
          content: Text(
            'Se descartará «${work.name}». Las sesiones guardadas se conservan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar trabajo'),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirmed != true ||
          repository != widget.workRepository) {
        return;
      }
    }
    final request = retry ? _discardAttempt : work;
    if (request == null) return;
    setState(() {
      _discardBusy = true;
      _discardAttempt = request;
      _discardError = null;
    });
    try {
      await repository.discard(request);
      if (!mounted || repository != widget.workRepository) return;
      setState(() {
        _discardAttempt = null;
        _works = _works.where((item) => item.id != request.id).toList();
      });
    } catch (error) {
      if (!mounted || repository != widget.workRepository) return;
      setState(() {
        if (error is WorkoutWorkConflict) {
          _discardAttempt = null;
          _discardError = 'El trabajo ha cambiado. Actualiza y revísalo antes de descartarlo.';
        } else {
          _discardError =
              'No se ha confirmado el descarte. Reintenta la misma petición. ${trainerError(error)}';
        }
      });
    } finally {
      if (mounted && repository == widget.workRepository) {
        setState(() => _discardBusy = false);
      }
    }
  }

  Future<void> _create() async {
    await context.push('/workouts/new');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis sesiones privadas'),
      actions: [
        IconButton(
          onPressed: _busy || _discardBusy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _frame(context, [
      const Text(
        'Tu biblioteca profesional. Las sesiones solo se comparten con los alumnos a los que las pautes.',
      ),
      const SizedBox(height: 16),
      if (widget.workRepository != null) ...[
        Text(
          'Trabajos incompletos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Retoma tus sesiones aunque tengan campos pendientes. Un envío sin confirmar conserva su receta hasta resolverlo.',
        ),
        if (_workError != null) Text('No se pudieron cargar: $_workError'),
        if (_discardError != null) Text(_discardError!),
        if (_discardAttempt != null && !_discardBusy)
          TextButton(
            onPressed: !_canCreate
                ? null
                : () => _discard(_discardAttempt!, retry: true),
            child: const Text('Reintentar mismo descarte'),
          ),
        if (_discardBusy) const LinearProgressIndicator(),
        if (!_busy && _workError == null && _works.isEmpty)
          const Text('No tienes trabajos incompletos guardados.'),
        for (final work in _works)
          Card(
            child: ListTile(
              title: Text(work.name),
              subtitle: Text(
                work.origin['parentWorkId'] != null
                    ? 'Sesión de un programa · retomar desde el programa'
                    : work.origin['assignmentId'] != null
                    ? 'Adaptación individual · borrador guardado'
                    : work.state['intent'] != null
                    ? 'Guardado pendiente de confirmar'
                    : 'Trabajo guardado · revisión ${work.revision}',
              ),
              onTap: _busy || _discardBusy
                  ? null
                  : () async {
                      final parent = work.origin['parentWorkId'] as String?;
                      final assignment = work.origin['assignmentId'] as String?;
                      await context.push(
                        parent != null
                            ? '/programs/work/${Uri.encodeComponent(parent)}'
                            : assignment != null
                            ? Uri(
                                path:
                                    '/assignments/${Uri.encodeComponent(assignment)}/adapt',
                                queryParameters: {'workId': work.id},
                              ).toString()
                            : '/workouts/work/${Uri.encodeComponent(work.id)}',
                      );
                      if (mounted) await _load();
                    },
              trailing: work.state['intent'] != null
                  ? null
                  : IconButton(
                      onPressed:
                          _busy ||
                              _discardBusy ||
                              !_canCreate ||
                              _discardAttempt != null
                          ? null
                          : () => _discard(work),
                      tooltip: 'Descartar trabajo ${work.name}',
                      icon: const Icon(Icons.delete_outline),
                    ),
            ),
          ),
        const SizedBox(height: 24),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy || _discardBusy || !_canCreate ? null : _create,
          icon: const Icon(Icons.add),
          label: const Text('Crear sesión privada'),
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) _retry(_error!, () => _load()),
      if (!_busy && _items.isEmpty && _error == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todavía no has creado sesiones privadas.'),
        ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar entre las sesiones cargadas',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ProfessionalCatalogGrid(
        children: [
          for (final item in _items.where(
            (item) => item.name.toLowerCase().contains(_query.toLowerCase()),
          ))
            Card(
              child: ListTile(
                title: Text(item.name),
                subtitle: Text('Versión ${item.version} · Privada'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () async {
                        await context.push('/workouts/${item.id}');
                        if (mounted) await _load();
                      },
              ),
            ),
        ],
      ),
      if (_more)
        OutlinedButton(
          onPressed: _busy ? null : () => _load(more: true),
          child: const Text('Cargar más sesiones'),
        ),
    ]),
  );
}

class TrainerWorkoutEditorPage extends StatefulWidget {
  const TrainerWorkoutEditorPage({
    super.key,
    required this.repository,
    this.templateId,
    this.onCreateExercise,
    this.exercisePreferences,
  });
  final TrainerWorkoutRepository repository;
  final String? templateId;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  State<TrainerWorkoutEditorPage> createState() =>
      _TrainerWorkoutEditorPageState();
}

class _TrainerWorkoutEditorPageState extends State<TrainerWorkoutEditorPage> {
  final _operationId = trainerOperationId();
  WorkoutTemplate? _template;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = widget.templateId == null
          ? null
          : await widget.repository.template(widget.templateId!);
      if (widget.templateId != null && value == null) {
        throw StateError('Sesión no disponible.');
      }
      if (mounted) setState(() => _template = value);
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesión privada')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _frame(context, [_retry(_error!, _load)]),
      );
    }
    final revision = widget.templateId != null;
    return WorkoutEditorPage(
      onCreateExercise: widget.onCreateExercise,
      exercisePreferences: widget.exercisePreferences,
      loadExercises: () => widget.repository.exercises(
        retainedIds: {
          for (final block in _template?.blocks ?? <WorkoutBlock>[])
            for (final item in block.items) item.exerciseId,
        },
      ),
      onSave: (input) => widget.repository.save(
        _operationId,
        input,
        previousId: widget.templateId,
      ),
      onSaved: (id) => context.pop(id),
      originalTemplate: _template,
      title: revision ? 'Revisar sesión privada' : 'Crear sesión privada',
      heading: 'Biblioteca del preparador',
      instructions: revision
          ? 'Se guarda una nueva versión. Las pautas anteriores conservan la receta que recibieron.'
          : 'Guárdala en tu biblioteca y después asígnala a tus alumnos.',
      saveLabel: revision ? 'Guardar nueva versión' : 'Guardar sesión privada',
      saveErrorMessage: 'No se pudo confirmar el guardado. Conservamos tu receta: reintenta sin cambiarla si la conexión falló.',
    );
  }
}

class TrainerWorkoutPreviewPage extends StatefulWidget {
  const TrainerWorkoutPreviewPage({
    super.key,
    required this.repository,
    required this.templateId,
  });
  final TrainerWorkoutRepository repository;
  final String templateId;
  @override
  State<TrainerWorkoutPreviewPage> createState() =>
      _TrainerWorkoutPreviewPageState();
}

class _TrainerWorkoutPreviewPageState extends State<TrainerWorkoutPreviewPage> {
  late Future<WorkoutTemplate?> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.template(widget.templateId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar receta')),
    body: FutureBuilder<WorkoutTemplate?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _frame(context, [
            _retry(
              'No se pudo cargar la sesión.',
              () => setState(() {
                _future = widget.repository.template(widget.templateId);
              }),
            ),
          ]);
        }
        return _frame(context, [
          WorkoutTemplateContent(template: snapshot.data!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final result = await context.push(
                '/workouts/${widget.templateId}/revise',
              );
              if (result != null && context.mounted) context.pop(true);
            },
            child: const Text('Crear nueva versión'),
          ),
        ]);
      },
    ),
  );
}

class TrainerClientWorkoutsPage extends StatefulWidget {
  const TrainerClientWorkoutsPage({
    super.key,
    required this.repository,
    required this.accessRepository,
    required this.clientId,
    this.programs,
    this.techniqueMode = false,
    this.resultsMode = false,
  });
  final TrainerWorkoutRepository repository;
  final TrainerRepository accessRepository;
  final String clientId;
  final TrainerProgramRepository? programs;
  final bool techniqueMode;
  final bool resultsMode;
  @override
  State<TrainerClientWorkoutsPage> createState() =>
      _TrainerClientWorkoutsPageState();
}

class _TrainerClientWorkoutsPageState extends State<TrainerClientWorkoutsPage> {
  List<TrainerAssignment> _items = [];
  TrainerRelation? _relation;
  bool _busy = true, _more = false, _effective = false;
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
      final access = await widget.accessRepository.access();
      final relations = await widget.accessRepository.clientRelations(
        widget.clientId,
      );
      final rows = await widget.repository.assignments(
        widget.clientId,
        before: more ? _items.last : null,
      );
      if (!mounted) return;
      setState(() {
        _relation = relations.isEmpty ? null : relations.first;
        _effective = access.effective;
        _items = more ? [..._items, ...rows] : rows;
        _more = rows.length == 50;
      });
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => TrainerAssignmentDialog(
        repository: widget.repository,
        relationId: _relation!.id,
      ),
    );
    if (assigned == true && mounted) await _load();
  }

  Future<void> _assignProgram() async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => TrainerProgramAssignmentDialog(
        repository: widget.programs!,
        relationId: _relation!.id,
      ),
    );
    if (assigned == true && mounted) await _load();
  }

  Future<void> _result(TrainerAssignment item) async {
    await context.push(
      '/clients/${widget.clientId}/workouts/${item.id}/result',
    );
    if (mounted) await _load();
  }

  Future<void> _conversation() async {
    if (_relation != null) {
      await context.push('/conversations/${_relation!.id}');
    }
  }

  Future<void> _cancel(TrainerAssignment item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EntrenaDialog(
        title: const Text('Retirar pauta pendiente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Se retirará ${item.name} de la agenda del alumno.'),
            const SizedBox(height: 16),
            EntrenaDialogActions(
              primaryLabel: 'Volver',
              onPrimary: () => Navigator.pop(dialogContext, false),
              secondary: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Retirar pauta'),
                ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(item.id);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = trainerError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.techniqueMode
            ? 'Vídeos de técnica por sesión'
            : widget.resultsMode
            ? 'Resultados de las sesiones'
            : 'Planificación y resultados',
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _frame(context, [
      Text(
        _relation?.name ?? 'Alumno',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        widget.techniqueMode
            ? 'Abre una sesión para ver los vídeos que el alumno ha compartido contigo. Si retiró la compartición, el clip deja de estar disponible.'
            : _relation?.endedAt == null
            ? 'Las pautas conviven con su planificación automática. Revisa las fechas antes de asignar.'
            : 'Servicio inactivo. Conservas las pautas y los resultados de tus etapas.',
      ),
      const SizedBox(height: 16),
      if (!widget.techniqueMode &&
          !widget.resultsMode &&
          _relation != null) ...[
        OutlinedButton.icon(
          onPressed: _busy ? null : _conversation,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Conversación del servicio'),
        ),
        const SizedBox(height: 12),
      ],
      if (!widget.techniqueMode && !widget.resultsMode)
        FilledButton.icon(
          onPressed:
              _busy ||
                  !_effective ||
                  _relation == null ||
                  _relation!.endedAt != null
              ? null
              : _assign,
          icon: const Icon(Icons.event_available),
          label: const Text('Asignar sesión privada'),
        ),
      if (!widget.techniqueMode &&
          !widget.resultsMode &&
          widget.programs != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              _busy ||
                  !_effective ||
                  _relation == null ||
                  _relation!.endedAt != null
              ? null
              : _assignProgram,
          icon: const Icon(Icons.view_week_outlined),
          label: const Text('Pautar programa privado'),
        ),
      ],
      const SizedBox(height: 16),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) _retry(_error!, () => _load()),
      if (!_busy &&
          _error == null &&
          ((widget.techniqueMode || widget.resultsMode)
              ? !_items.any((i) => i.executionId != null)
              : _items.isEmpty))
        Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            widget.techniqueMode
                ? (_more
                      ? 'No hay sesiones con ejecución en esta página. Puedes cargar más sesiones.'
                      : 'Todavía no hay sesiones con ejecución que consultar.')
                : widget.resultsMode
                ? (_more
                      ? 'No hay resultados en esta página. Puedes cargar más pautas.'
                      : 'Todavía no hay resultados registrados para consultar.')
                : 'Todavía no has pautado sesiones a este alumno.',
          ),
        ),
      for (final item in _items.where(
        (i) =>
            (!widget.techniqueMode && !widget.resultsMode) ||
            i.executionId != null,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EntrenaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${trainerDate(item.date)} · ${item.statusLabel} · Versión ${item.version}',
                ),
                if (item.note?.isNotEmpty == true) Text(item.note!),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.executionId != null && !widget.techniqueMode)
                      TextButton(
                        onPressed: _busy ? null : () => _result(item),
                        child: const Text('Ver resultados'),
                      ),
                    if (item.executionId != null)
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push(
                                '/assignments/${item.id}/technique',
                              ),
                        icon: const Icon(Icons.video_library_outlined),
                        label: const Text('Ver vídeos compartidos'),
                      ),
                    if (!widget.techniqueMode &&
                        !widget.resultsMode &&
                        item.status == 'planned')
                      TextButton(
                        onPressed: _busy ? null : () => _cancel(item),
                        child: const Text('Retirar pauta'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (_more)
        OutlinedButton(
          onPressed: _busy ? null : () => _load(more: true),
          child: const Text('Cargar más pautas'),
        ),
    ]),
  );
}

class TrainerAssignmentDialog extends StatefulWidget {
  const TrainerAssignmentDialog({
    super.key,
    required this.repository,
    required this.relationId,
    this.initialWorkout,
    this.initialDate,
  });
  final TrainerWorkoutRepository repository;
  final String relationId;
  final TrainerWorkout? initialWorkout;
  final DateTime? initialDate;
  @override
  State<TrainerAssignmentDialog> createState() =>
      _TrainerAssignmentDialogState();
}

class _TrainerAssignmentDialogState extends State<TrainerAssignmentDialog> {
  final _note = TextEditingController();
  List<TrainerWorkout> _workouts = [];
  TrainerWorkout? _selected;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _operationId, _error;
  bool _busy = true, _more = false;
  TrainerWorkout? _cursor;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialWorkout;
    _date = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
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
      final rows = await widget.repository.workouts(
        before: more ? _cursor : null,
      );
      if (mounted) {
        setState(() {
          _workouts = more
              ? [..._workouts, ...rows]
              : {
                  if (widget.initialWorkout != null)
                    widget.initialWorkout!.id: widget.initialWorkout!,
                  for (final row in rows) row.id: row,
                }.values.toList();
          _more = rows.length == 50;
          _cursor = rows.lastOrNull;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    _operationId ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.assign(
        id: _operationId!,
        relationId: widget.relationId,
        templateId: _selected!.id,
        date: _date,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar la pauta. Reintenta con estos mismos datos. ${trainerError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final template = await widget.repository.template(selected.id);
      if (!mounted) return;
      if (template == null) throw StateError('Sesión no disponible.');
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => EntrenaDialog(
          title: const Text('Receta que recibirá el alumno'),
          content: WorkoutTemplateContent(template: template),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver a la pauta'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: EntrenaDialog(
      title: const Text('Asignar sesión privada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          const Text(
            'El alumno recibirá esta versión en su agenda. Su plan automático se conserva.',
          ),
          const SizedBox(height: 16),
          if (_workouts.isEmpty && !_busy && _error == null)
            const Text('Crea primero una sesión en Mis sesiones privadas.'),
          RadioGroup<String>(
            groupValue: _selected?.id,
            onChanged: (value) {
              if (!_busy && _operationId == null) {
                setState(
                  () => _selected = _workouts.firstWhere(
                    (item) => item.id == value,
                  ),
                );
              }
            },
            child: Column(
              children: [
                for (final item in _workouts)
                  RadioListTile<String>(
                    title: Text(item.name),
                    subtitle: Text('Versión ${item.version}'),
                    value: item.id,
                    enabled: !_busy && _operationId == null,
                  ),
              ],
            ),
          ),
          if (_more)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Cargar más sesiones'),
            ),
          if (_selected != null)
            TextButton(
              onPressed: _busy ? null : _preview,
              child: const Text('Ver receta antes de asignar'),
            ),
          OutlinedButton(
            onPressed: _busy || _operationId != null
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2200, 12, 31),
                    );
                    if (date != null && mounted) setState(() => _date = date);
                  },
            child: Text('Fecha: ${trainerDate(_date)}'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            enabled: !_busy && _operationId == null,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Indicaciones para el alumno (opcional)',
            ),
          ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 16),
          EntrenaDialogActions(
            primaryLabel: _operationId == null
                ? 'Asignar sesión'
                : 'Reintentar asignación',
            onPrimary: _busy || _selected == null ? null : _assign,
            secondary: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
            ],
          ),
        ],
      ),
      actions: const [],
    ),
  );
}

Widget _frame(BuildContext context, List<Widget> children) => Center(
  child: ConstrainedBox(
    constraints: ProfessionalWorkspaceScope.pageConstraints(
      context,
      maxWidth: 1000,
    ),
    child: ListView(padding: const EdgeInsets.all(24), children: children),
  ),
);
Widget _retry(String error, VoidCallback onRetry) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Column(
    children: [
      Text(error),
      TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  ),
);
