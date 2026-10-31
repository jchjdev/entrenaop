import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import 'trainer_calendar_date.dart';
import 'trainer_operations_repository.dart';
import 'trainer_workout_repository.dart';

Future<void> showTrainerMoveDialog(
  BuildContext context,
  TrainerOperationsRepository repository,
  TrainerAssignment assignment,
  DateTime destination,
) async {
  final detail = await repository.assignment(assignment.id);
  final preview = await repository.previewChange(
    assignment: assignment,
    date: destination,
    note: assignment.note,
  );
  if (!context.mounted) return;
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MoveDialog(
      repository: repository,
      assignment: assignment,
      destination: destination,
      clientName: detail.clientName,
      preview: preview,
    ),
  );
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.repository,
    required this.assignment,
    required this.destination,
    required this.clientName,
    required this.preview,
  });
  final TrainerOperationsRepository repository;
  final TrainerAssignment assignment;
  final DateTime destination;
  final String clientName;
  final TrainerAssignmentChangePreview preview;
  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  final _operation = trainerOperationId();
  String? _reason;
  @override
  Widget build(BuildContext context) => RetainedSaveDialog<bool>(
    errorMessage:
        'No se ha confirmado el cambio. Reintenta esta misma operación.',
    save: (_) async {
      try {
        await widget.repository.change(
          operationId: _operation,
          assignment: widget.assignment,
          date: widget.destination,
          fingerprint: widget.preview.fingerprint,
          note: widget.assignment.note,
        );
      } catch (e) {
        if (mounted) setState(() => _reason = trainerError(e));
        rethrow;
      }
    },
    builder: (context, submit, saving, error, markDirty) => AlertDialog(
      title: const Text('Mover pauta pendiente'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.assignment.name} · ${widget.clientName}'),
          Text(
            '${trainerCalendarDate(widget.assignment.date)} → ${trainerCalendarDate(widget.destination)}',
          ),
          if (widget.preview.hasDateCoincidence)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Ese día ya hay otra sesión en su agenda. Ambas se conservarán; confirma que quieres añadir esta coincidencia.',
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Solo se moverá si sigue pendiente y sin iniciar. La biblioteca se conserva.',
            ),
          ),
          if (saving) const LinearProgressIndicator(),
          if (error != null) Text(_reason ?? error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.maybePop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: saving ? null : () => submit(true),
          child: Text(
            error == null ? 'Confirmar cambio' : 'Reintentar el mismo cambio',
          ),
        ),
      ],
    ),
  );
}

class TrainerAssignmentAdaptationPage extends StatefulWidget {
  const TrainerAssignmentAdaptationPage({
    super.key,
    required this.operations,
    required this.workouts,
    required this.assignmentId,
    this.onCreateExercise,
    this.exercisePreferences,
  });
  final TrainerOperationsRepository operations;
  final TrainerWorkoutRepository workouts;
  final String assignmentId;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  State<TrainerAssignmentAdaptationPage> createState() =>
      _TrainerAssignmentAdaptationPageState();
}

class _TrainerAssignmentAdaptationPageState
    extends State<TrainerAssignmentAdaptationPage> {
  final _operation = trainerOperationId();
  final _editorExit = WorkflowExitController();
  WorkflowExitController? _parentExit;
  CreatePersonalWorkoutInput? _pending;
  TrainerAssignmentChangePreview? _preview;
  bool _saving = false, _finished = false;
  String? _saveError;
  late Future<(TrainerAssignmentContext, WorkoutTemplate)> _future = _load();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = WorkflowExitScope.maybeOf(context);
    if (_parentExit != next) {
      _parentExit?.onExit = null;
      _parentExit = next;
      _parentExit?.onExit = _requestExit;
    }
  }

  @override
  void dispose() {
    _parentExit?.onExit = null;
    super.dispose();
  }

  Future<bool> _requestExit() async {
    if (_finished) return true;
    if (_saving) return false;
    if (_pending == null) {
      return await (_editorExit.onExit?.call() ?? Future.value(true));
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Adaptación sin confirmar'),
            content: const Text(
              'La respuesta del guardado no está confirmada. Puedes continuar el reintento o salir y consultar el estado de la pauta en la agenda.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir y consultar agenda'),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<String> _submit(
    CreatePersonalWorkoutInput input,
    TrainerAssignmentContext detail,
  ) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (_preview == null) {
        final preview = await widget.operations.previewChange(
          assignment: detail.assignment,
          date: detail.assignment.date,
          note: detail.assignment.note,
          recipe: input,
        );
        if (!mounted) throw StateError('La edición se ha cerrado.');
        if (preview.hasDateCoincidence) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Revisar coincidencia'),
              content: const Text(
                'Ese día hay otra sesión en su agenda. Esta adaptación conserva ambas. Confirma que quieres continuar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Seguir editando'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar adaptación'),
                ),
              ],
            ),
          );
          if (confirmed != true) {
            throw StateError('Adaptación sin enviar. Puedes seguir editando.');
          }
        }
        _preview = preview;
        _pending = input;
      }
      await widget.operations.change(
        operationId: _operation,
        assignment: detail.assignment,
        date: detail.assignment.date,
        fingerprint: _preview!.fingerprint,
        note: detail.assignment.note,
        recipe: _pending,
      );
      return detail.assignment.id;
    } catch (e) {
      if (mounted) setState(() => _saveError = trainerError(e));
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _finish() {
    _finished = true;
    context.canPop() ? context.pop(true) : context.go('/agenda');
  }

  Future<(TrainerAssignmentContext, WorkoutTemplate)> _load() async {
    final detail = await widget.operations.assignment(widget.assignmentId);
    if (detail.assignment.status != 'planned' ||
        detail.assignment.executionId != null) {
      throw StateError('Solo se adapta una pauta pendiente sin iniciar.');
    }
    final template = await widget.workouts.template(
      detail.assignment.templateId,
    );
    if (template == null) throw StateError('Receta no disponible.');
    return (detail, template);
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(TrainerAssignmentContext, WorkoutTemplate)>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Adaptar pauta')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'La pauta no está disponible para editar. Actualiza para comprobar su estado.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _future = _load();
                  }),
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        );
      }
      final (detail, template) = snapshot.data!;
      return Stack(
        children: [
          AbsorbPointer(
            absorbing: _pending != null,
            child: WorkflowExitScope(
              controller: _editorExit,
              child: WorkoutEditorPage(
                loadWarmups: widget.workouts.warmups,
                loadExercises: () => widget.workouts.exercises(
                  retainedIds: {
                    for (final block in template.blocks)
                      for (final item in block.items) item.exerciseId,
                  },
                ),
                onCreateExercise: widget.onCreateExercise,
                exercisePreferences: widget.exercisePreferences,
                originalTemplate: template,
                title: 'Adaptar pauta de ${detail.clientName}',
                heading:
                    'Solo esta entrega · ${trainerCalendarDate(detail.assignment.date)}',
                instructions: 'Se crea una receta para esta pauta. Tu biblioteca, el programa y el resto de alumnos conservan sus versiones.',
                saveLabel: 'Guardar adaptación individual',
                saveErrorMessage: 'No se ha confirmado la adaptación. Reintenta sin cambiar la receta; si el alumno ya empezó o cambió la pauta, actualiza la agenda.',
                onSave: (input) => _submit(input, detail),
                onSaved: (_) => _finish(),
              ),
            ),
          ),
          if (_pending != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saving) const LinearProgressIndicator(),
                      Text(_saveError ?? 'Confirmando la adaptación…'),
                      if (!_saving) ...[
                        const Text(
                          'La receta queda conservada. Reintenta el mismo envío para confirmar sin crear otra adaptación.',
                        ),
                        FilledButton(
                          onPressed: () async {
                            try {
                              await _submit(_pending!, detail);
                              if (mounted) _finish();
                            } catch (_) {
                              /* El error permanece junto al envío retenido. */
                            }
                          },
                          child: const Text('Reintentar la misma adaptación'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await _requestExit() && mounted) _finish();
                          },
                          child: const Text('Salir y consultar agenda'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class TrainerReviewQueuePage extends StatefulWidget {
  const TrainerReviewQueuePage({
    super.key,
    required this.repository,
    this.clientId,
  });
  final TrainerOperationsRepository repository;
  final String? clientId;
  @override
  State<TrainerReviewQueuePage> createState() => _TrainerReviewQueuePageState();
}

class _TrainerReviewQueuePageState extends State<TrainerReviewQueuePage> {
  List<TrainerReviewItem> _items = [];
  bool _busy = true, _more = false;
  String? _error;
  bool _matches(TrainerReviewItem item) =>
      widget.clientId == null || item.clientId == widget.clientId;
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
      final rows = await widget.repository.reviews(
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 100;
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
      title: Text(
        widget.clientId == null
            ? 'Resultados por revisar'
            : 'Resultados del alumno por revisar',
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Revisa lo realizado antes de marcarlo. Si el alumno corrige sus resultados, la pauta vuelve a esta bandeja.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
        if (!_busy && _items.where(_matches).isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _more
                  ? 'No hay resultados de este alumno entre los cargados. Carga más para continuar.'
                  : 'No hay resultados pendientes de revisión${widget.clientId == null ? '' : ' de este alumno'}.',
            ),
          ),
        if (_items.isNotEmpty)
          Text(
            '${_items.where(_matches).length} resultados en esta selección${_more ? ' · listado parcial, carga más para continuar' : ''}',
          ),
        ProfessionalCatalogGrid(
          minCardWidth: 340,
          children: [
            for (final item in _items.where(_matches))
              ProfessionalResourceCard(
                leading: const ProfessionalResourceIcon(
                  Icons.fact_check_outlined,
                ),
                title: Text(item.clientName),
                subtitle: Text(
                  '${item.assignment.name} · ${trainerCalendarDate(item.assignment.date)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () async {
                        await context.push(
                          '/clients/${item.clientId}/workouts/${item.assignment.id}/result${widget.clientId == null ? '?review=all' : ''}',
                        );
                        if (mounted) await _load();
                      },
              ),
          ],
        ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más resultados'),
          ),
      ],
    ),
  );
}

Future<bool> showTrainerReviewDialog(
  BuildContext context,
  TrainerOperationsRepository repository,
  String assignmentId,
  int resultRevision,
  String? previousNote, {
  String confirmLabel = 'Marcar revisado',
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReviewDialog(
          repository: repository,
          assignmentId: assignmentId,
          revision: resultRevision,
          previousNote: previousNote,
          confirmLabel: confirmLabel,
        ),
      ) ??
      false;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.repository,
    required this.assignmentId,
    required this.revision,
    this.previousNote,
    required this.confirmLabel,
  });
  final TrainerOperationsRepository repository;
  final String assignmentId;
  final int revision;
  final String? previousNote;
  final String confirmLabel;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _operation = trainerOperationId();
  late final _note = TextEditingController(text: widget.previousNote);
  String? _pending, _reason;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RetainedSaveDialog<bool>(
    errorMessage: 'No se ha confirmado la revisión. Conservamos el envío para reintentar.',
    save: (_) async {
      _pending ??= _note.text;
      try {
        await widget.repository.markReviewed(
          operationId: _operation,
          assignmentId: widget.assignmentId,
          resultRevision: widget.revision,
          privateNote: _pending,
        );
      } catch (e) {
        if (mounted) setState(() => _reason = trainerError(e));
        rethrow;
      }
    },
    builder: (context, submit, saving, error, markDirty) => AlertDialog(
      title: const Text('Marcar resultado revisado'),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La nota es privada. El alumno no recibe este texto. Para darle indicaciones utiliza su conversación.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              enabled: !saving && _pending == null,
              maxLength: 2000,
              maxLines: 4,
              onChanged: (_) => markDirty(true),
              decoration: const InputDecoration(
                labelText: 'Nota interna opcional',
              ),
            ),
            if (saving) const LinearProgressIndicator(),
            if (error != null) Text(_reason ?? error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.maybePop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: saving ? null : () => submit(true),
          child: Text(
            error == null ? widget.confirmLabel : 'Reintentar la revisión',
          ),
        ),
      ],
    ),
  );
}
