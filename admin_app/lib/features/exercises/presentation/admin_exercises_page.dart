import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/core/catalog_search.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';
import 'package:workout_editor_ui/exercise_labels_dialog.dart';
import 'package:workout_editor_ui/exercise_collections.dart';

import '../../../core/admin_shell.dart';

import '../data/admin_exercise_video_repository.dart';
import 'admin_exercise_dialog.dart';

class AdminExercisesPage extends StatefulWidget {
  const AdminExercisesPage({
    super.key,
    required this.repository,
    this.videos,
    this.initialExerciseId,
    this.preferences,
  });

  final AdminExerciseRepository repository;
  final String? initialExerciseId;
  final AdminExerciseVideoRepository? videos;
  final ExerciseCatalogPreferences? preferences;

  @override
  State<AdminExercisesPage> createState() => _AdminExercisesPageState();
}

class _AdminExercisesPageState extends State<AdminExercisesPage> {
  bool _loading = true;
  bool _initialOpened = false;
  bool _saving = false;
  String? _error;
  List<AdminCatalogExercise> _exercises = const [];
  final _search = TextEditingController();
  String? _collection;
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

  @override
  Widget build(BuildContext context) => Scaffold(
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
        child: _buildContent(),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : _openEditor,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo ejercicio'),
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
                                ...exercise.muscleGroups,
                                ...exercise.equipment,
                              ].join(' · '),
                            ),
                            trailing: _preferences?.supportsLabels != true
                                ? const Icon(Icons.edit_outlined)
                                : IconButton(
                                    tooltip: 'Etiquetas: ${exercise.name}',
                                    icon: const Icon(Icons.label_outline),
                                    onPressed: _saving
                                        ? null
                                        : () => editExerciseLabels(
                                            context,
                                            _preferences!,
                                            exercise.id,
                                            exercise.name,
                                          ),
                                  ),
                            onTap: _saving ? null : () => _openEditor(exercise),
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
