import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/guided_program_editor_adapter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';

import '../../../core/admin_shell.dart';
import '../../../core/catalog_search.dart';

import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../../workouts/presentation/admin_session_library_status.dart';
import '../domain/admin_guided_repository.dart';
import '../domain/admin_guided_work.dart';
import '../domain/admin_guided_trash.dart';
import '../../editorial_covers/domain/program_cover.dart';
import '../../editorial_covers/presentation/program_cover_editor.dart';
import 'guided_category_editor.dart';
import 'admin_guided_program_card.dart';
import 'guided_session_workspace.dart';
import '../../exercises/data/admin_exercise_repository.dart';
import '../../exercises/data/admin_exercise_video_repository.dart';

class AdminGuidedCatalogPage extends StatefulWidget {
  const AdminGuidedCatalogPage({
    super.key,
    required this.repository,
    this.warmups = false,
    this.covers,
    this.workRepository,
    this.trashRepository,
  });
  final AdminGuidedRepository repository;
  final bool warmups;
  final ProgramCoverRepository? covers;
  final AdminGuidedWorkRepository? workRepository;
  final AdminGuidedTrashRepository? trashRepository;
  @override
  State<AdminGuidedCatalogPage> createState() => _AdminGuidedCatalogPageState();
}

class _AdminGuidedCatalogPageState extends State<AdminGuidedCatalogPage> {
  List<GuidedProgram>? _programs;
  List<GuidedWarmup>? _warmups;
  String? _error;
  bool _busy = false;
  List<GuidedWork> _work = [];
  String? _workError;
  final _search = TextEditingController();
  GuidedProgramMode? _mode;
  String _statusFilter = 'all';

  List<GuidedProgram> get _visiblePrograms => (_programs ?? <GuidedProgram>[])
      .where(
        (p) =>
            (_mode == null || p.mode == _mode) &&
            (_statusFilter == 'all' || p.status == _statusFilter) &&
            matchesCatalogSearch(_search.text, [
              p.name,
              p.description,
              p.audience,
              p.equipment,
              ...p.categories.map((c) => c.name),
            ]),
      )
      .toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.warmups) {
        final items = await widget.repository.warmups();
        if (mounted) {
          setState(() {
            _warmups = items;
            _error = null;
          });
        }
      } else {
        final items = await widget.repository.programs();
        try {
          _work = await widget.workRepository?.list() ?? [];
          _workError = null;
        } catch (_) {
          _workError = 'No se pudieron cargar tus borradores de trabajo. Pulsa Actualizar para reintentar.';
        }
        if (mounted) {
          setState(() {
            _programs = items;
            _error = null;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el catálogo.');
    }
  }

  Future<void> _open(String suffix) async {
    await context.push(
      '${widget.warmups ? '/warmups' : '/guided-programs'}/$suffix',
    );
    if (mounted) await _load();
  }

  Future<void> _status(GuidedProgram p, String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.setStatus(p.id!, status);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cambiar el estado. Revisa que las sesiones y calentamientos sigan publicados.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cover(GuidedProgram p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ProgramCoverEditor(
          programId: p.id!,
          programName: p.name,
          repository: widget.covers!,
          editorTitle: 'Imagen del programa',
          headerTitle: 'Cabecera del programa',
          cardLabel: p.modeLabel,
          cardCategory: p.primaryCategory?.name,
          cardDetail: '${p.sessionCount} sesiones',
          cardAction: 'Ver programa →',
          cardIcon: p.mode == GuidedProgramMode.guide
              ? Icons.fitness_center_rounded
              : Icons.trending_up_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(
            title: Text(
              widget.warmups ? 'Calentamientos' : 'Programas guiados',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/programs'),
            ),
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.warmups
                  ? 'Calentamientos reutilizables'
                  : 'Programas guiados',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              widget.warmups
                  ? 'Cada guardado conserva una versión. Puedes asignarla a varias sesiones.'
                  : 'Organiza sesiones del catálogo en rutinas repetibles o recorridos por fases.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _open('new'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    widget.warmups
                        ? 'Crear calentamiento'
                        : 'Crear programa guiado',
                  ),
                ),
                if (!AdminShellScope.hidesAppBar(context))
                  OutlinedButton(
                    onPressed: () => context.push(
                      widget.warmups ? '/guided-programs' : '/warmups',
                    ),
                    child: Text(
                      widget.warmups
                          ? 'Programas guiados'
                          : 'Gestionar calentamientos',
                    ),
                  ),
                if (!widget.warmups)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            await manageGuidedCategories(
                              context,
                              widget.repository,
                            );
                            if (mounted) await _load();
                          },
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Categorías'),
                  ),
                if (!widget.warmups && widget.trashRepository != null)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _open('trash'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Papelera'),
                  ),
                if (!widget.warmups)
                  IconButton.outlined(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.warmups && widget.workRepository != null) ...[
              if (_workError != null) Text(_workError!),
              if (_work.isNotEmpty) ...[
                Text(
                  'Continuar trabajando',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Borradores privados, todavía fuera del catálogo. Se conservan aunque estén incompletos.',
                ),
                for (final work in _work)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            work.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (work.updatedAt != null)
                            Text(
                              'Guardado: ${work.updatedAt!.toLocal().toString().substring(0, 16)}',
                            ),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _open('work/${work.id}'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Continuar'),
                              ),
                              TextButton(
                                onPressed: _busy ? null : () => _discard(work),
                                child: const Text('Mover a papelera'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ],
            if (!widget.warmups) ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar programas',
                  hintText: 'Nombre, categoría o descripción',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (mode, label) in <(GuidedProgramMode?, String)>[
                    (null, 'Todos'),
                    (GuidedProgramMode.guide, 'Rutinas'),
                    (GuidedProgramMode.phased, 'Por fases'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Todos los estados'),
                        ),
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Borradores'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Publicados'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Retirados'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_programs?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_visiblePrograms.length} de ${_programs!.length} programas · ${_programs!.where((p) => p.status == 'published').length} publicados · ${_programs!.where((p) => p.status == 'draft').length} borradores',
                  ),
                ),
            ],
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (_programs == null && _warmups == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_programs?.isNotEmpty == true && _visiblePrograms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No hay programas con esta búsqueda y filtros.'),
              ),
            for (final p in _visiblePrograms)
              AdminGuidedProgramCard(
                program: p,
                onEdit: _busy ? null : () => _open('${p.id}/edit'),
                onReview: _busy ? null : () => _open('${p.id}/review'),
                onRetire: _busy ? null : () => _status(p, 'archived'),
                onTrash: widget.trashRepository == null || _busy
                    ? null
                    : () => _moveToTrash(
                        p.name,
                        () => widget.trashRepository!.trashProgram(p.id!),
                        family: true,
                      ),
                onCover: widget.covers == null || _busy
                    ? null
                    : () => _cover(p),
              ),
            for (final w in _warmups ?? <GuidedWarmup>[])
              Card(
                child: ListTile(
                  title: Text(w.name),
                  subtitle: Text('Versión ${w.version}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _open('${w.id}/edit'),
                ),
              ),
            if (_programs?.isEmpty == true || _warmups?.isEmpty == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Todavía no hay contenido. Crea el primero desde aquí.',
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _discard(GuidedWork work) => _moveToTrash(
    work.name,
    () => widget.workRepository!.discard(work),
    family: false,
  );

  Future<void> _moveToTrash(
    String name,
    Future<void> Function() move, {
    required bool family,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => EntrenaDialog(
          title: const Text('¿Mover a papelera?'),
          content: Text(
            family
                ? 'Se retirarán del catálogo todas las versiones de «$name» y se ocultarán sus trabajos vinculados. Podrás recuperarlos desde Papelera. Las sesiones reutilizadas y los resultados se conservan.'
                : '«$name» saldrá de Continuar trabajando y podrás recuperarlo desde Papelera. Sus sesiones y el programa de origen se conservan.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Mover a papelera',
              onPrimary: () => Navigator.of(ctx).pop(true),
              secondary: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      await move();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Programa movido a la papelera.'),
          action: widget.trashRepository == null
              ? null
              : SnackBarAction(
                  label: 'Ver papelera',
                  onPressed: () => _open('trash'),
                ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar el movimiento. Actualiza el catálogo para comprobar su estado antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Adaptador oficial: publicación, categorías y navegación pertenecen a ADMIN.
class AdminGuidedEditorPage extends StatelessWidget {
  const AdminGuidedEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    this.original,
    this.workRepository,
    this.work,
    this.exerciseRepository,
    this.exerciseVideos,
    this.exercisePreferences,
  });
  final AdminGuidedRepository repository;
  final AdminWorkoutRepository workouts;
  final GuidedProgram? original;
  final AdminGuidedWorkRepository? workRepository;
  final GuidedWork? work;
  final AdminExerciseRepository? exerciseRepository;
  final AdminExerciseVideoRepository? exerciseVideos;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  Widget build(BuildContext context) => GuidedProgramEditorPage(
    repository: repository,
    workouts: workouts,
    original: original,
    workRepository: workRepository,
    work: work,
    adapter: _AdminProgramAdapter(
      repository,
      workouts,
      exerciseRepository,
      exerciseVideos,
      exercisePreferences,
    ),
  );
}

class _AdminProgramAdapter extends GuidedProgramEditorAdapter {
  const _AdminProgramAdapter(
    this.repository,
    this.workouts,
    this.exerciseRepository,
    this.exerciseVideos,
    this.exercisePreferences,
  );
  final AdminGuidedRepository repository;
  final AdminWorkoutRepository workouts;
  final AdminExerciseRepository? exerciseRepository;
  final AdminExerciseVideoRepository? exerciseVideos;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  Future<void> openSession(
    BuildContext context, {
    required String programName,
    String? sessionId,
    required bool duplicate,
    required Future<void> Function(String) onSaved,
  }) async {
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GuidedSessionWorkspace(
        exerciseRepository: exerciseRepository,
        exerciseVideos: exerciseVideos,
        exercisePreferences: exercisePreferences,
        workouts: workouts,
        programName: programName,
        sessionId: sessionId,
        duplicate: duplicate,
        onSaved: onSaved,
      ),
    );
  }

  @override
  void finish(BuildContext context, String id, bool review) {
    if (review) {
      context.go('/guided-programs/${Uri.encodeComponent(id)}/review');
    } else {
      context.canPop() ? context.pop(true) : context.go('/guided-programs');
    }
  }

  @override
  Future<void> openLibrary(BuildContext context) async {
    await context.push('/sessions');
  }

  @override
  void openPrograms(BuildContext context) {
    context.push('/guided-programs');
  }

  @override
  Future<String?> createWarmup(BuildContext context) =>
      context.push<String>('/warmups/new?returnId=true');
  @override
  Future<GuidedProgramCategory?> createCategory(BuildContext context) =>
      editGuidedCategory(context, repository);
  @override
  Future<void> manageCategories(BuildContext context) =>
      manageGuidedCategories(context, repository);
  @override
  Widget sessionStatus(ProgramSessionSummary? session) =>
      AdminSessionLibraryStatus(session: session);
  @override
  bool definitiveError(Object error) =>
      error is PostgrestException &&
      ['22023', '23503', '42501'].contains(error.code);
  @override
  String? visibilityError(Object error) =>
      error is PostgrestException ? error.message : null;
}
