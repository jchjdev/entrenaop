import 'trainer_catalog_search.dart';

import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/guided_program_editor_adapter.dart';
import 'package:workout_editor_ui/guided_program_work.dart';
import 'package:workout_editor_ui/program_session_catalog.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_template_content.dart';
import 'package:workout_core/workout_template.dart';

import 'trainer_program_repository.dart';
import 'trainer_program_date_plan.dart';
import 'trainer_workout_repository.dart';
import 'trainer_session_work_editor.dart';
import 'trainer_catalog_trash_page.dart';
import 'trainer_catalog_trash_repository.dart';

class TrainerProgramDetailPage extends StatefulWidget {
  const TrainerProgramDetailPage({
    super.key,
    required this.repository,
    required this.workouts,
    required this.programId,
    this.trashRepository,
  });
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final String programId;
  final TrainerCatalogTrashRepository? trashRepository;
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
              onPressed: () => setState(() {
                _program = widget.repository.program(widget.programId);
              }),
              child: const Text('No se pudo cargar el programa. Reintentar'),
            ),
          );
        }
        return _programFrame(context, [
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
              if (widget.trashRepository case final repository?)
                TrainerCatalogTrashAction(
                  repository: repository,
                  kind: TrainerCatalogKind.program,
                  id: p.id!,
                  name: p.name,
                  onTrashed: () async {
                    context.canPop()
                        ? context.pop(true)
                        : context.go('/programs');
                  },
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
    this.workRepository,
    this.trashRepository,
    this.trashOpen = false,
  });
  final TrainerProgramRepository repository;
  final TrainerRepository access;
  final GuidedWorkRepository? workRepository;
  final TrainerCatalogTrashRepository? trashRepository;
  final bool trashOpen;
  @override
  State<TrainerProgramLibraryPage> createState() =>
      _TrainerProgramLibraryPageState();
}

class _TrainerProgramLibraryPageState extends State<TrainerProgramLibraryPage> {
  final _catalogSearch = TrainerCatalogSearch();
  String _query = '';
  final _search = TextEditingController();
  List<TrainerProgram> _items = [];
  List<GuidedWork> _works = [];
  bool _busy = true, _more = false, _canCreate = false;
  bool _reloadAfterTrash = false;
  bool _discardBusy = false;
  GuidedWork? _discardAttempt;
  String? _error, _workError, _discardError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrainerProgramLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trashOpen && !widget.trashOpen) {
      if (_busy) {
        _reloadAfterTrash = true;
      } else {
        _load();
      }
    }
  }

  @override
  void dispose() {
    _catalogSearch.dispose();
    _search.dispose();
    super.dispose();
  }

  void _searchCatalog() {
    setState(() => _busy = true);
    _catalogSearch.schedule(() => _load(catalogOnly: true));
  }

  Future<void> _load({bool more = false, bool catalogOnly = false}) async {
    final request = _catalogSearch.begin();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.access.access();
      final rows = await widget.repository.programs(
        before: more ? _items.last : null,
        query: _query,
      );
      List<GuidedWork>? works;
      String? workError;
      if (widget.workRepository != null && !more && !catalogOnly) {
        try {
          works = await widget.workRepository!.list();
        } catch (error) {
          workError = trainerError(error);
        }
      }
      if (mounted && _catalogSearch.current(request)) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
          _canCreate = access.effective;
          if (works != null) _works = works;
          if (!more && !catalogOnly) _workError = workError;
        });
      }
    } catch (e) {
      if (mounted && _catalogSearch.current(request)) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted && _catalogSearch.current(request)) {
        if (_reloadAfterTrash) {
          _reloadAfterTrash = false;
          await _load();
        } else {
          setState(() => _busy = false);
        }
      }
    }
  }

  Future<void> _discard(GuidedWork work, {bool retry = false}) async {
    final repository = widget.workRepository;
    if (_busy || _discardBusy || !_canCreate || repository == null) return;
    if (!retry) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar trabajo incompleto'),
          content: Text(
            'Se descartará «${work.name}». Sus sesiones de la biblioteca se conservan.',
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
          repository != widget.workRepository ||
          confirmed != true) {
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
        if (error is GuidedWorkConflict) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis programas privados'),
      actions: [
        if (widget.trashRepository != null)
          IconButton(
            onPressed: _busy || _discardBusy || _discardAttempt != null
                ? null
                : () async {
                    await context.push('/programs/trash');
                    if (mounted) await _load();
                  },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Papelera de programas',
          ),
        IconButton(
          onPressed: _busy || _discardBusy ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: trainerCatalogAutoPage(
      active: _query.trim().isNotEmpty,
      hasMore: _more,
      busy: _busy,
      loadMore: () => _load(more: true),
      child: _programFrame(context, [
        const Text(
          'Organiza sesiones por rutinas o fases y reutiliza cada programa con tus alumnos. Cada pauta conserva la versión asignada.',
        ),
        const SizedBox(height: 16),
        if (widget.workRepository != null &&
            (_busy ||
                _works.isNotEmpty ||
                _workError != null ||
                _discardError != null ||
                _discardAttempt != null)) ...[
          Text(
            'Trabajos incompletos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Continúa los montajes guardados aunque tengan campos pendientes. Las sesiones creadas dentro se gestionan en su biblioteca.',
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
                subtitle: Text('Trabajo guardado · revisión ${work.revision}'),
                onTap: _discardBusy
                    ? null
                    : () async {
                        await context.push(
                          '/programs/work/${Uri.encodeComponent(work.id)}',
                        );
                        if (mounted) await _load();
                      },
                trailing: IconButton(
                  onPressed:
                      _busy ||
                          _discardBusy ||
                          !_canCreate ||
                          _discardAttempt != null
                      ? null
                      : () => _discard(work),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Descartar trabajo ${work.name}',
                ),
              ),
            ),
          if (_works.length == 100)
            const Text(
              'Se han cargado 100 trabajos. Puede haber más; conservan su enlace de recuperación.',
            ),
          const SizedBox(height: 24),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy || !_canCreate
                ? null
                : () async {
                    await context.push('/programs/new');
                    if (mounted) await _load();
                  },
            icon: const Icon(Icons.add),
            label: const Text('Crear programa privado'),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar en todos mis programas',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                setState(() => _query = v);
                _searchCatalog();
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_busy && _error == null && _items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _query.trim().isNotEmpty
                  ? 'No hay programas que coincidan con la búsqueda.'
                  : 'Todavía no has creado programas privados.',
            ),
          ),
        ProfessionalCatalogGrid(
          children: [
            for (final row in _items)
              ProfessionalResourceCard(
                leading: const ProfessionalResourceIcon(
                  Icons.view_week_outlined,
                ),
                title: Text(row.program.name),
                subtitle: Text(
                  '${row.program.modeLabel} · ${row.program.sessionCount} sesiones · v${row.program.version}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () async {
                        await context.push('/programs/${row.program.id}');
                        if (mounted) await _load();
                      },
              ),
          ],
        ),
        if (_more && !(_query.trim().isNotEmpty))
          OutlinedButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más programas'),
          ),
      ]),
    ),
  );
}

class TrainerProgramEditorPage extends StatefulWidget {
  const TrainerProgramEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    this.programId,
    this.onCreateExercise,
    this.exercisePreferences,
    this.workRepository,
    this.work,
    this.sessionWorkRepository,
    this.onSaved,
  });
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final String? programId;
  final ValueChanged<String>? onSaved;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  final GuidedWorkRepository? workRepository;
  final GuidedWork? work;
  final WorkoutEditorWorkRepository? sessionWorkRepository;
  @override
  State<TrainerProgramEditorPage> createState() =>
      _TrainerProgramEditorPageState();
}

class _TrainerProgramEditorPageState extends State<TrainerProgramEditorPage> {
  late Future<GuidedProgram?> _initial = _load();
  TrainerProgramComposition? _composition;
  Future<GuidedProgram?> _load() async {
    final base = widget.work == null
        ? widget.programId
        : widget.work!.baseProgramId;
    final original = base == null
        ? null
        : await widget.repository.program(base);
    _composition = _TrainerRecoveredProgramComposition(
      widget.repository,
      widget.workouts,
      original: original,
      work: widget.work,
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
              onPressed: () => setState(() {
                _initial = _load();
              }),
              child: const Text('No se pudo cargar el programa. Reintentar'),
            ),
          ),
        );
      }
      return GuidedProgramEditorPage(
        repository: _composition!,
        workouts: _composition!,
        original: snapshot.data,
        workRepository: widget.workRepository,
        work: widget.work,
        adapter: _TrainerProgramAdapter(
          widget.workouts,
          widget.onCreateExercise,
          widget.exercisePreferences,
          widget.sessionWorkRepository,
          widget.onSaved,
        ),
      );
    },
  );
}

/// Completa únicamente referencias del checkpoint con lecturas autorizadas.
/// El estado crudo continúa perteneciendo al creador compartido, no se convierte
/// a GuidedProgram ni se pierden valores incompletos de semanas/descansos.
class _TrainerRecoveredProgramComposition extends TrainerProgramComposition {
  _TrainerRecoveredProgramComposition(
    super.repository,
    super.workouts, {
    super.original,
    this.work,
  });
  final GuidedWork? work;

  @override
  Future<List<ProgramSessionSummary>> listGeneral() async {
    final rows = await super.listGeneral();
    final known = rows.map((row) => row.id).toSet();
    final references = <String>{};
    final phases = work?.state['phases'];
    if (phases is List) {
      for (final phase in phases.whereType<Map>()) {
        final sessions = phase['sessions'];
        if (sessions is List) {
          for (final session in sessions.whereType<Map>()) {
            if (session['id'] is String) {
              references.add(session['id'] as String);
            }
          }
        }
        final pending = phase['pending'];
        if (pending is List) references.addAll(pending.whereType<String>());
      }
    }
    for (final id in references) {
      if (!known.add(id)) continue;
      final template = await workouts.template(id);
      if (template == null) continue;
      rows.add(
        ProgramSessionSummary(
          id: template.id,
          name: template.name,
          status: 'published',
          version: template.version,
          isRunning: template.blocks.any(
            (block) => block.format == WorkoutBlockFormat.running,
          ),
          catalogScope: 'private',
          supportsAdjustableRest: false,
          showInLibrary: false,
        ),
      );
    }
    return rows;
  }
}

class _TrainerProgramAdapter extends GuidedProgramEditorAdapter {
  const _TrainerProgramAdapter(
    this.workouts,
    this.onCreateExercise,
    this.exercisePreferences,
    this.sessionWorkRepository,
    this.onSaved,
  );
  final TrainerWorkoutRepository workouts;
  final ValueChanged<String>? onSaved;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  final WorkoutEditorWorkRepository? sessionWorkRepository;
  @override
  bool get recoverableSessions => sessionWorkRepository != null;
  @override
  Future<void> openSessionWork(
    BuildContext context, {
    required String workId,
    required Map<String, dynamic> origin,
    required String programName,
    required Future<void> Function(String) onSaved,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PrivateSessionWorkspace(
      repository: workouts,
      sessionId: null,
      duplicate: false,
      onSaved: onSaved,
      onCreateExercise: onCreateExercise,
      exercisePreferences: exercisePreferences,
      workId: workId,
      origin: origin,
      workRepository: sessionWorkRepository,
    ),
  );
  @override
  Future<void> discardSessionWork(String workId) async {
    final work = await sessionWorkRepository!.load(workId);
    if (work != null && !work.discarded) {
      await sessionWorkRepository!.discard(work);
    }
  }

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
        onCreateExercise: onCreateExercise,
        exercisePreferences: exercisePreferences,
        sessionId: sessionId,
        duplicate: copy,
        onSaved: onSaved,
      ),
    );
  }

  @override
  void finish(BuildContext context, String id, bool review) {
    if (onSaved != null) {
      onSaved!(id);
    } else {
      context.canPop() ? context.pop(true) : context.go('/programs');
    }
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
      error is GuidedWorkConflict ||
      error is PostgrestException &&
          ['22023', '23503', '42501', '40001'].contains(error.code);
}

class _PrivateSessionWorkspace extends StatefulWidget {
  const _PrivateSessionWorkspace({
    required this.repository,
    required this.sessionId,
    required this.duplicate,
    required this.onSaved,
    this.onCreateExercise,
    this.exercisePreferences,
    this.workId,
    this.origin,
    this.workRepository,
  });
  final TrainerWorkoutRepository repository;
  final String? sessionId;
  final bool duplicate;
  final Future<void> Function(String) onSaved;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  final String? workId;
  final Map<String, dynamic>? origin;
  final WorkoutEditorWorkRepository? workRepository;
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
  Widget build(BuildContext context) =>
      ProfessionalWorkspaceViewport(builder: _buildWorkspace);

  Widget _buildWorkspace(BuildContext context) => PopScope<void>(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1020,
        ),
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
              child: ProfessionalEmbeddedScroll(
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
                    : widget.workRepository != null && widget.workId != null
                    ? WorkflowExitScope(
                        controller: _exit,
                        child: TrainerSessionWorkEditor(
                          workId: widget.workId!,
                          initialOrigin: widget.origin,
                          repository: widget.workRepository!,
                          workouts: widget.repository,
                          onSaved: _link,
                          onCreateExercise: widget.onCreateExercise,
                          exercisePreferences: widget.exercisePreferences,
                          embedded: true,
                          saveLabel: 'Guardar e incorporar sesión',
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
                              onCreateExercise: widget.onCreateExercise,
                              exercisePreferences: widget.exercisePreferences,
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
    this.initialDate,
    this.initialProgram,
  });
  final TrainerProgramRepository repository;
  final String relationId;
  final DateTime? initialDate;
  final GuidedProgram? initialProgram;
  @override
  State<TrainerProgramAssignmentDialog> createState() =>
      _TrainerProgramAssignmentDialogState();
}

class _TrainerProgramAssignmentDialogState
    extends State<TrainerProgramAssignmentDialog> {
  final _catalogSearch = TrainerCatalogSearch();
  String _programQuery = '';
  final _programSearch = TextEditingController();
  final _note = TextEditingController();
  List<TrainerProgram> _programs = [];
  GuidedProgram? _program;
  int _phase = -1;
  final _entries = <TrainerProgramEntry>[];
  bool _busy = false, _more = false;
  bool _libraryLoaded = false;
  String? _error, _operation;
  @override
  void initState() {
    super.initState();
    if (widget.initialProgram != null) {
      _choose(widget.initialProgram!);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _catalogSearch.dispose();
    _programSearch.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final request = _catalogSearch.begin();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.programs(
        before: more ? _programs.last : null,
        query: _programQuery,
      );
      if (mounted && _catalogSearch.current(request)) {
        setState(() {
          _programs = more ? [..._programs, ...rows] : rows;
          _more = rows.length == 50;
          _libraryLoaded = true;
        });
      }
    } catch (e) {
      if (mounted && _catalogSearch.current(request)) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted && _catalogSearch.current(request)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeProgram() async {
    if (_busy || _operation != null) return;
    setState(() {
      _program = null;
      _entries.clear();
    });
    if (!_libraryLoaded) await _load();
  }

  void _choose(GuidedProgram program, {int? phase}) {
    final today = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    setState(() {
      _program = program;
      _phase = phase ?? (program.sessionCount > 256 ? 0 : -1);
      _entries.clear();
      _entries.addAll(proposeTrainerProgramDates(program, _phase, today));
    });
  }

  Future<void> _moveStart() async {
    if (_busy || _operation != null || _entries.isEmpty) return;
    final first = _entries
        .map((entry) => entry.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final chosen = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
    );
    if (chosen == null || !mounted) return;
    // El desplazamiento conserva días civiles, también al cambiar la hora.
    final offset = DateTime.utc(
      chosen.year,
      chosen.month,
      chosen.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    final shifted = [
      for (final entry in _entries)
        TrainerProgramEntry(
          entry.phase,
          entry.session,
          DateTime(entry.date.year, entry.date.month, entry.date.day + offset),
        ),
    ];
    if (shifted.any((entry) => entry.date.isAfter(DateTime(2100, 12, 31)))) {
      setState(
        () => _error = 'La última sesión quedaría fuera del calendario admitido. Elige una fecha anterior.',
      );
      return;
    }
    setState(() {
      _entries
        ..clear()
        ..addAll(shifted);
      _error = null;
    });
  }

  Widget _schedulePreview() {
    final days = <DateTime, List<TrainerProgramEntry>>{};
    for (final entry in _entries) {
      final day = DateUtils.dateOnly(entry.date);
      (days[day] ??= []).add(entry);
    }
    final dates = days.keys.toList()..sort();
    if (dates.isEmpty) return const SizedBox.shrink();
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen de la pauta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${_entries.length} ${_entries.length == 1 ? 'sesión' : 'sesiones'} · ${dates.length} ${dates.length == 1 ? 'fecha' : 'fechas'} · ${_date(dates.first)} – ${_date(dates.last)}',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('program-shift-start'),
                onPressed: _busy || _operation != null ? null : _moveStart,
                icon: const Icon(Icons.event_outlined),
                label: const Text('Cambiar inicio de toda la pauta'),
              ),
            ),
            const Text(
              'Conserva la separación entre las fechas que has elegido.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final date in dates.take(7))
                  SizedBox(
                    width: 190,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weekdays[date.weekday - 1]} ${_date(date)}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            for (final entry in days[date]!)
                              Text(_sessionName(entry)),
                            if (days[date]!.length > 1)
                              Text(
                                '${days[date]!.length} sesiones el mismo día: revisa la carga.',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (dates.length > 7)
              Text(
                'Vista previa de las primeras 7 de ${dates.length} fechas. Todas las sesiones y sus fechas se revisan debajo.',
              ),
          ],
        ),
      ),
    );
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
  Widget build(BuildContext context) => trainerCatalogAutoPage(
    active: _programQuery.trim().isNotEmpty,
    hasMore: _more,
    busy: _busy,
    loadMore: () => _load(more: true),
    child: PopScope<bool>(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
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
                      TextField(
                        controller: _programSearch,
                        decoration: const InputDecoration(
                          labelText: 'Buscar en todos mis programas',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _programQuery = value;
                            _busy = true;
                          });
                          _catalogSearch.schedule(() => _load());
                        },
                      ),
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
                      if (_program!.description.isNotEmpty)
                        Text(_program!.description),
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
                                if (value != null) {
                                  _choose(_program!, phase: value);
                                }
                              },
                      ),
                      if (_program!.sessionCount > 256)
                        const Text(
                          'Este programa se pauta por fases. Cada envío admite hasta 256 sesiones con fechas concretas.',
                        ),
                      TextButton(
                        onPressed: _busy || _operation != null
                            ? null
                            : _changeProgram,
                        child: const Text('Elegir otro programa'),
                      ),
                      _schedulePreview(),
                      const SizedBox(height: 12),
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
                                    _program!
                                        .phases[_entries[i].phase]
                                        .instructions,
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
                                              final chosen =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate: old.date,
                                                    firstDate: DateTime(2020),
                                                    lastDate: DateTime(2100),
                                                  );
                                              if (chosen != null && mounted) {
                                                setState(
                                                  () => _entries[i] =
                                                      TrainerProgramEntry(
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
                                          : () => setState(
                                              () => _entries.removeAt(i),
                                            ),
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
                          onPressed:
                              _busy || _operation != null || _entries.isEmpty
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
                                  _entries.addAll(
                                    copies.take(256 - _entries.length),
                                  );
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
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_program == null)
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Reintentar carga'),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_program != null)
                      FilledButton(
                        onPressed: _busy || _entries.isEmpty ? null : _assign,
                        child: Text(
                          _operation == null
                              ? 'Confirmar ${_entries.length} ${_entries.length == 1 ? 'sesión' : 'sesiones'}'
                              : 'Comprobar y reintentar planificación',
                        ),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Volver al alumno'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _programFrame(BuildContext context, List<Widget> children) => Center(
  child: ConstrainedBox(
    constraints: ProfessionalWorkspaceScope.pageConstraints(
      context,
      maxWidth: 900,
    ),
    child: ListView(padding: const EdgeInsets.all(20), children: children),
  ),
);
