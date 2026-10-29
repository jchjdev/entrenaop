import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/core/catalog_search.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';
import 'package:workout_editor_ui/exercise_labels_dialog.dart';
import 'package:workout_editor_ui/exercise_collections.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import '../../../core/admin_shell.dart';

import '../data/admin_exercise_video_repository.dart';
import '../data/admin_exercise_trash_repository.dart';
import 'admin_exercise_dialog.dart';

class AdminExercisesPage extends StatefulWidget {
  const AdminExercisesPage({
    super.key,
    required this.repository,
    this.videos,
    this.initialExerciseId,
    this.preferences,
    this.ownerKey,
  });

  final AdminExerciseRepository repository;
  final String? initialExerciseId;
  final AdminExerciseVideoRepository? videos;
  final ExerciseCatalogPreferences? preferences;
  final Object? ownerKey;

  @override
  State<AdminExercisesPage> createState() => _AdminExercisesPageState();
}

class _AdminExercisesPageState extends State<AdminExercisesPage> {
  bool _loading = true;
  bool _initialOpened = false;
  bool _saving = false;
  bool _confirming = false;
  String? _error;
  List<AdminCatalogExercise> _exercises = const [];
  final _search = TextEditingController();
  String? _collection;
  _ExerciseTrashAttempt? _trashAttempt;
  bool get _busy => _saving || _confirming;
  bool get _blocked => _busy || _trashAttempt != null;
  AdminExerciseTrashRepository? get _trashRepository =>
      widget.repository is AdminExerciseTrashRepository
      ? widget.repository as AdminExerciseTrashRepository
      : null;
  late final _preferences = widget.preferences == null
      ? null
      : ExercisePreferencesController(widget.preferences!);
  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  List<AdminCatalogExercise> get _visibleExercises => _exercises
      .where(
        (exercise) =>
            matchesExerciseCollection(
              _preferences?.labels(exercise.id) ?? const [],
              _collection,
            ) &&
            matchesCatalogSearch(_search.text, [
              exercise.name,
              ...exercise.muscleGroups,
              ...exercise.equipment,
              exercise.exerciseType,
              ...?_preferences?.labels(exercise.id),
            ]),
      )
      .toList();

  @override
  void dispose() {
    _preferences?.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _preferences?.addListener(_preferencesChanged);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _exercises.isEmpty;
      _error = null;
    });
    try {
      final exercises = await widget.repository.listOfficial();
      await _preferences?.load();
      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        _loading = false;
      });
      if (!_initialOpened && widget.initialExerciseId != null) {
        _initialOpened = true;
        final target = exercises
            .where((e) => e.id == widget.initialExerciseId)
            .firstOrNull;
        if (target == null) {
          setState(
            () => _error = 'El ejercicio solicitado no está disponible.',
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openEditor(target);
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo oficial.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([AdminCatalogExercise? exercise]) async {
    if (_blocked) return;
    final result = await showAdminExerciseDialog(
      context,
      repository: widget.repository,
      videos: widget.videos,
      exercise: exercise,
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exercise == null
                ? 'Ejercicio oficial creado.'
                : 'Ejercicio oficial actualizado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Comprueba el permiso y los datos.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _trashExercise(
    AdminCatalogExercise exercise, {
    bool retry = false,
  }) async {
    final repository = _trashRepository;
    if (_busy ||
        repository == null ||
        (!retry && _trashAttempt != null) ||
        (retry && _trashAttempt == null)) {
      return;
    }
    final owner = widget.ownerKey ?? widget.repository;
    bool current() =>
        mounted &&
        owner == (widget.ownerKey ?? widget.repository) &&
        identical(repository, _trashRepository);
    try {
      if (!retry) {
        setState(() => _confirming = true);
        final confirmed = await showCatalogTrashConfirmation(
          context,
          name: exercise.name,
          kindLabel: 'ejercicio',
          description:
              'Dejará de ofrecerse para nuevas creaciones. Las sesiones, programas '
              'y resultados existentes conservarán el ejercicio. Puedes recuperarlo '
              'desde la papelera.',
        );
        if (!confirmed || !current()) return;
        _trashAttempt = _ExerciseTrashAttempt(exercise, newGuidedWorkId());
      }
      setState(() {
        _confirming = false;
        _saving = true;
        _error = null;
      });
      final attempt = _trashAttempt!;
      await repository.trashExercise(
        attempt.exercise.id,
        operationId: attempt.operationId,
      );
      if (!current()) return;
      setState(() => _trashAttempt = null);
      await _load();
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ejercicio movido a la papelera.')),
      );
    } catch (error) {
      if (!current()) return;
      setState(() {
        if (error is FormatException) _trashAttempt = null;
        _error = error is FormatException
            ? error.message
            : 'No se pudo confirmar el traslado. Reintenta para comprobarlo.';
      });
    } finally {
      if (current()) {
        setState(() {
          _saving = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    isBusy: () => _busy,
    hasUnsavedChanges: () => _trashAttempt != null,
    title: '¿Salir con un traslado sin confirmar?',
    message: 'Todavía no conocemos el resultado del traslado. Puedes reintentarlo aquí. Si sales, comprueba el catálogo y la papelera al volver.',
    child: Scaffold(
      appBar: AdminShellScope.hidesAppBar(context)
          ? null
          : AppBar(
              title: const Text('Administración · ejercicios'),
              leading: GoRouter.maybeOf(context)?.canPop() == false
                  ? IconButton(
                      tooltip: 'Ir a programas',
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () => context.go('/programs'),
                    )
                  : null,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(
            context,
            maxWidth: 900,
          ),
          child: Column(
            children: [
              if (_trashAttempt case final attempt?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: EntrenaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Traslado de «${attempt.exercise.name}» sin confirmar.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Actualizar el catálogo no confirma ni descarta esta operación.',
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _trashExercise(
                                  attempt.exercise,
                                  retry: true,
                                ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar traslado'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _blocked ? null : _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ejercicio'),
      ),
    ),
  );

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final visible = _visibleExercises;
    return Column(
      children: [
        if (_trashRepository != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar catálogo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _blocked
                        ? null
                        : () => context.go('/exercises/trash'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Papelera'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar ejercicios',
              hintText: 'Nombre, grupo muscular o material',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Reintentar')),
        if (_preferences?.labelsLoaded == true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExerciseCollections(
              memberships: _exercises
                  .map((e) => _preferences!.labels(e.id))
                  .toList(),
              selected: _collection,
              onChanged: (value) => setState(() => _collection = value),
            ),
          ),
        if (_preferences?.labelsError case final error?) Text(error),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _exercises.isEmpty
                        ? 'Todavía no hay ejercicios oficiales.'
                        : 'No hay ejercicios con esa búsqueda.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  children: [
                    ProfessionalCatalogGrid(
                      children: [
                        for (final exercise in visible)
                          ProfessionalResourceCard(
                            leading: _ExerciseImage(url: exercise.imageUrl),
                            title: Text(exercise.name),
                            subtitle: Text(
                              [
                                if (!exercise.isPublic)
                                  'Retirado · revisar para publicar',
                                ...exercise.muscleGroups,
                                ...exercise.equipment,
                              ].join(' · '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_preferences?.supportsLabels == true)
                                  IconButton(
                                    tooltip: 'Etiquetas: ${exercise.name}',
                                    icon: const Icon(Icons.label_outline),
                                    onPressed: _blocked
                                        ? null
                                        : () => editExerciseLabels(
                                            context,
                                            _preferences!,
                                            exercise.id,
                                            exercise.name,
                                          ),
                                  ),
                                if (_trashRepository != null)
                                  PopupMenuButton<String>(
                                    enabled: !_blocked,
                                    tooltip: 'Más opciones de ${exercise.name}',
                                    onSelected: (_) => _trashExercise(exercise),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'trash',
                                        child: Text('Mover a papelera'),
                                      ),
                                    ],
                                  )
                                else if (_preferences?.supportsLabels != true)
                                  const Icon(Icons.edit_outlined),
                              ],
                            ),
                            onTap: _blocked
                                ? null
                                : () => _openEditor(exercise),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ExerciseTrashAttempt {
  const _ExerciseTrashAttempt(this.exercise, this.operationId);
  final AdminCatalogExercise exercise;
  final String operationId;
}

class _ExerciseImage extends StatelessWidget {
  const _ExerciseImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 64,
      height: 48,
      child: url == null
          ? ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.fitness_center_outlined),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    ),
  );
}
