import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/catalog_search.dart';
import 'package:workout_editor_ui/exercise_collections.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';
import 'package:workout_editor_ui/exercise_labels_dialog.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/exercise_video_preview.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

import 'trainer_exercise_repository.dart';
import 'trainer_exercise_muscles.dart';
import 'trainer_catalog_trash_page.dart';
import 'trainer_catalog_trash_repository.dart';
import 'trainer_workout_repository.dart';
import 'trainer_media_page.dart';
import 'trainer_media_repository.dart';

/// El creador común recibe únicamente un ejercicio privado ya confirmado.
Future<WorkoutEditorExercise?> showTrainerExerciseEditor(
  BuildContext context,
  TrainerExerciseRepository repository, {
  TrainerExercise? previous,
  ExerciseVideoSource? videoSource,
  TrainerMediaRepository? mediaRepository,
  String? initialVideoUrl,
}) async {
  WorkoutEditorExercise? saved;
  await showDialog<ExerciseFormSubmission<ExerciseDraft>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProfessionalWorkspaceViewport(
      builder: (_) => _ExerciseDialog(
        repository: repository,
        previous: previous,
        videoSource: videoSource,
        mediaRepository: mediaRepository,
        initialVideoUrl: initialVideoUrl,
        onSaved: (id, draft) {
          saved = WorkoutEditorExercise(
            id: id,
            name: draft.name,
            muscleGroups: trainerExerciseMuscles(draft.muscleGroups),
            equipment: draft.equipment,
            catalogScope: 'Míos',
          );
        },
      ),
    ),
  );
  return saved;
}

class TrainerExercisePage extends StatefulWidget {
  const TrainerExercisePage({
    super.key,
    required this.repository,
    required this.access,
    this.videoSource,
    this.mediaRepository,
    this.preferences,
    this.trashRepository,
    this.trashOpen = false,
    this.onCleanup,
  });
  final TrainerExerciseRepository repository;
  final TrainerRepository access;
  final ExerciseVideoSource? videoSource;
  final TrainerMediaRepository? mediaRepository;
  final ExerciseCatalogPreferences? preferences;
  final TrainerCatalogTrashRepository? trashRepository;
  final bool trashOpen;
  final Future<void> Function()? onCleanup;
  @override
  State<TrainerExercisePage> createState() => _TrainerExercisePageState();
}

class _TrainerExercisePageState extends State<TrainerExercisePage> {
  List<TrainerExercise> _items = [];
  List<TrainerExercise> _official = [];
  bool _showOfficial = false, _officialBusy = false, _officialLoaded = false;
  String? _officialError;
  TrainerExerciseUsage? _usage;
  bool _busy = true, _enabled = false;
  bool _reloadAfterTrash = false;
  bool _canOrganize = false;
  String _query = '';
  final _search = TextEditingController();
  String? _label, _muscle, _equipment;
  late final _preferences = widget.preferences == null
      ? null
      : ExercisePreferencesController(widget.preferences!);
  String? _error;

  @override
  void initState() {
    super.initState();
    _preferences?.addListener(_preferencesChanged);
    _load();
  }

  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TrainerExercisePage oldWidget) {
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
    _search.dispose();
    _preferences?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final access = await widget.access.access();
      final usage = await widget.repository.usage();
      final items = await widget.repository.list();
      await _preferences?.load();
      if (mounted) {
        setState(() {
          _items = items.where((e) => e.current).toList();
          _usage = usage;
          _enabled = access.effective && usage.exercises < usage.exerciseLimit;
          _canOrganize = access.effective;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerExerciseError(e));
    } finally {
      if (mounted) {
        if (_reloadAfterTrash) {
          _reloadAfterTrash = false;
          await _load();
        } else {
          setState(() => _busy = false);
        }
      }
    }
  }

  Future<void> _edit([TrainerExercise? previous]) async {
    await showTrainerExerciseEditor(
      context,
      widget.repository,
      previous: previous,
      videoSource: widget.videoSource,
      mediaRepository: widget.mediaRepository,
    );
    if (mounted) await _load();
  }

  Future<void> _loadOfficial() async {
    setState(() {
      _officialBusy = true;
      _officialError = null;
    });
    try {
      final items = await widget.repository.officialCatalog();
      if (mounted) {
        setState(() {
          _official = items;
          _officialLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _officialError = trainerExerciseError(error));
    } finally {
      if (mounted) setState(() => _officialBusy = false);
    }
  }

  Future<void> _inspect(TrainerExercise exercise) async {
    final edit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExerciseDetails(
        exercise: exercise,
        videoSource: widget.videoSource,
        canEdit: !exercise.official && _enabled,
        trashRepository: !exercise.official && _canOrganize
            ? widget.trashRepository
            : null,
      ),
    );
    if (edit == true && mounted) await _edit(exercise);
    if (edit == false && mounted) await _load();
  }

  Map<String, String> _filterOptions(Iterable<String> values) {
    final options = <String, String>{};
    for (final value in values) {
      final key = normalizeCatalogSearch(value);
      if (key.isNotEmpty) options.putIfAbsent(key, () => value.trim());
    }
    return Map.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Widget _filter(
    String label,
    String allLabel,
    Map<String, String> options,
    String? selected,
    ValueChanged<String?> changed,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected'),
      initialValue: selected ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => changed(value == '' ? null : value),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = _showOfficial ? _official : _items;
    final muscleGroups = {
      for (final exercise in catalog)
        exercise.id: trainerExerciseMuscles(exercise.draft.muscleGroups),
    };
    final muscleOptions = _filterOptions(muscleGroups.values.expand((m) => m));
    final equipmentOptions = _filterOptions(
      catalog.expand((e) => e.draft.equipment),
    );
    final muscle = muscleOptions.containsKey(_muscle) ? _muscle : null;
    final equipment = equipmentOptions.containsKey(_equipment)
        ? _equipment
        : null;
    final visible = catalog
        .where((e) {
          final muscles = muscleGroups[e.id]!;
          return (muscle == null ||
                  muscles.any(
                    (value) => normalizeCatalogSearch(value) == muscle,
                  )) &&
              (equipment == null ||
                  e.draft.equipment.any(
                    (value) => normalizeCatalogSearch(value) == equipment,
                  )) &&
              matchesCatalogSearch(_query, [
                e.draft.name,
                ...trainerExerciseMuscleSearchTerms(muscles),
                ...e.draft.equipment,
                ...?_preferences?.labels(e.id),
              ]) &&
              matchesExerciseCollection(
                _preferences?.labels(e.id) ?? const [],
                _label,
              );
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejercicios'),
        actions: [
          if (widget.trashRepository != null)
            IconButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await context.push('/exercises/trash');
                      if (mounted) await _load();
                    },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Papelera de ejercicios propios',
            ),
          IconButton(
            onPressed: _showOfficial
                ? (_officialBusy ? null : _loadOfficial)
                : (_busy ? null : _load),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(
            context,
            maxWidth: 900,
          ),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Mis ejercicios'),
                    selected: !_showOfficial,
                    onSelected: (_) => setState(() {
                      _showOfficial = false;
                      _label = _muscle = _equipment = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('EntrenaOP'),
                    selected: _showOfficial,
                    onSelected: (_) {
                      setState(() {
                        _showOfficial = true;
                        _label = _muscle = _equipment = null;
                      });
                      if (!_officialLoaded && !_officialBusy) _loadOfficial();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_showOfficial) ...[
                const Text(
                  'Catálogo de EntrenaOP. Puedes utilizar estos ejercicios directamente al crear tus sesiones y programas; no necesitas copiarlos.',
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'Tu biblioteca privada para preparar sesiones y programas de tus alumnos.',
                ),
                const SizedBox(height: 16),
                if (_usage case final usage?)
                  Text(
                    '${usage.exercises}/${usage.exerciseLimit} ejercicios y versiones · ${usage.images}/${usage.imageLimit} imágenes reservadas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const ExpansionTile(
                  key: PageStorageKey('trainer-exercise-storage-help'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('Límites y conservación'),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Las versiones anteriores conservan el historial y cuentan en el límite. Cada imagen ocupa como máximo 500 KB; las reservas de subidas también cuentan. La limpieza retira solo archivos sin otros usos y libera su reserva tras confirmar el borrado. Puedes enlazar un vídeo HTTPS o subir una demostración. Los enlaces externos dependen de la disponibilidad y privacidad de ese proveedor.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy || !_enabled ? null : _edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Crear ejercicio privado'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.onCleanup != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            await widget.onCleanup!();
                            if (mounted) await _load();
                          },
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Limpiar archivos sin uso'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: _showOfficial
                          ? 'Buscar en EntrenaOP'
                          : 'Buscar en mis ejercicios',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                ),
              ),
              if (muscleOptions.isNotEmpty || equipmentOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (muscleOptions.isNotEmpty)
                      _filter(
                        'Músculo',
                        'Todos los músculos',
                        muscleOptions,
                        muscle,
                        (value) => setState(() => _muscle = value),
                      ),
                    if (equipmentOptions.isNotEmpty)
                      _filter(
                        'Material',
                        'Todo el material',
                        equipmentOptions,
                        equipment,
                        (value) => setState(() => _equipment = value),
                      ),
                  ],
                ),
              ],
              if (_preferences?.labelsLoaded == true)
                ExerciseCollections(
                  memberships: (_showOfficial ? _official : _items)
                      .map((e) => _preferences!.labels(e.id))
                      .toList(),
                  selected: _label,
                  onChanged: (v) => setState(() => _label = v),
                ),
              if (!_showOfficial)
                if (_preferences?.labelsError case final error?) Text(error),
              if (_showOfficial ? _officialBusy : _busy)
                const LinearProgressIndicator(),
              if (_showOfficial && _officialError != null) ...[
                Text(_officialError!),
                TextButton(
                  onPressed: _loadOfficial,
                  child: const Text('Reintentar'),
                ),
              ],
              if (!_showOfficial && _error != null) ...[
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
              if (!_showOfficial && !_busy && _items.isEmpty && _error == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Todavía no has creado ejercicios propios.'),
                ),
              if (catalog.isNotEmpty && visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay ejercicios con estos filtros.'),
                ),
              ProfessionalCatalogGrid(
                minCardWidth: 320,
                children: [
                  for (final exercise in visible)
                    ProfessionalResourceCard(
                      leading: ExerciseThumbnail(
                        url: exercise.imageUrl,
                        size: 56,
                      ),
                      title: Text(exercise.draft.name),
                      subtitle: Text(
                        [
                          if (exercise.official)
                            'EntrenaOP'
                          else
                            'Versión ${exercise.version}',
                          ...muscleGroups[exercise.id]!,
                          ...?_preferences?.labels(exercise.id),
                        ].join(' · '),
                      ),
                      trailing: _preferences == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: 'Etiquetas: ${exercise.draft.name}',
                              icon: const Icon(Icons.label_outline),
                              onPressed: _busy || !_canOrganize
                                  ? null
                                  : () => editExerciseLabels(
                                      context,
                                      _preferences,
                                      exercise.id,
                                      exercise.draft.name,
                                    ),
                            ),
                      onTap: () => _inspect(exercise),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseDetails extends StatefulWidget {
  const _ExerciseDetails({
    required this.exercise,
    required this.canEdit,
    this.videoSource,
    this.trashRepository,
  });
  final TrainerExercise exercise;
  final bool canEdit;
  final ExerciseVideoSource? videoSource;
  final TrainerCatalogTrashRepository? trashRepository;

  @override
  State<_ExerciseDetails> createState() => _ExerciseDetailsState();
}

class _ExerciseDetailsState extends State<_ExerciseDetails> {
  bool _pending = false;
  TrainerExercise get exercise => widget.exercise;
  ExerciseVideoSource? get videoSource => widget.videoSource;
  TrainerCatalogTrashRepository? get trashRepository => widget.trashRepository;
  bool get canEdit => widget.canEdit && !_pending;

  @override
  Widget build(BuildContext context) {
    final draft = exercise.draft;
    final image = exercise.imageUrl;
    final video = Uri.tryParse(draft.videoUrl ?? '');
    return PopScope(
      canPop: !_pending,
      child: AlertDialog(
        title: Text(draft.name),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null &&
                    Uri.tryParse(image)?.scheme == 'https') ...[
                  SizedBox(
                    height: 300,
                    child: InteractiveViewer(
                      child: Image.network(
                        image,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'No se pudo cargar la foto. Actualiza la biblioteca para reintentar.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  exercise.official
                      ? 'Catálogo de EntrenaOP · Solo consulta'
                      : 'Tu ejercicio privado · Versión ${exercise.version}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Músculos: ${trainerExerciseMuscles(draft.muscleGroups).join(' · ')}',
                ),
                Text(
                  'Material: ${draft.equipment.isEmpty ? 'Sin material' : draft.equipment.join(' · ')}',
                ),
                Text('Dificultad: ${draft.difficulty} · ${draft.exerciseType}'),
                if (draft.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(draft.description!),
                ],
                if (video?.scheme == 'https') ...[
                  const SizedBox(height: 16),
                  if (video!.host.endsWith('.b-cdn.net') && videoSource != null)
                    ExerciseVideoPreview(
                      url: draft.videoUrl!,
                      source: videoSource!,
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        var opened = false;
                        try {
                          opened = await launchUrl(
                            video,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          /* El proveedor externo puede no estar disponible. */
                        }
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el vídeo.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ver vídeo'),
                    ),
                ],
                if (exercise.official) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Disponible en el selector de ejercicios del creador de sesiones. Al incluir esa sesión en un programa, se conserva la misma referencia.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!exercise.official)
            if (trashRepository case final repository?)
              TrainerCatalogTrashAction(
                repository: repository,
                kind: TrainerCatalogKind.exercise,
                id: exercise.id,
                name: draft.name,
                onPendingChanged: (pending) =>
                    setState(() => _pending = pending),
                onTrashed: () async => Navigator.of(context).pop(false),
              ),
          TextButton(
            onPressed: _pending ? null : () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar ejercicio'),
            ),
        ],
      ),
    );
  }
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({
    required this.repository,
    required this.onSaved,
    this.previous,
    this.videoSource,
    this.mediaRepository,
    this.initialVideoUrl,
  });
  final TrainerExerciseRepository repository;
  final void Function(String, ExerciseDraft) onSaved;
  final TrainerExercise? previous;
  final ExerciseVideoSource? videoSource;
  final TrainerMediaRepository? mediaRepository;
  final String? initialVideoUrl;
  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _operation = trainerOperationId();
  ExerciseFormSubmission<ExerciseDraft>? _pending;
  String? _reason;
  @override
  Widget build(
    BuildContext context,
  ) => RetainedSaveDialog<ExerciseFormSubmission<ExerciseDraft>>(
    errorMessage: 'No se ha confirmado el guardado. Conservamos el envío para reintentarlo sin duplicados.',
    save: (submission) async {
      setState(() {
        _pending ??= submission;
        _reason = null;
      });
      try {
        final id = await widget.repository.save(
          _operation,
          _pending!,
          previous: widget.previous,
        );
        widget.onSaved(id, _pending!.draft);
      } catch (error) {
        if (mounted) setState(() => _reason = trainerExerciseError(error));
        rethrow;
      }
    },
    builder: (context, submit, saving, error, markDirty) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ProfessionalWorkspaceScope.isDesktop(context) ? 1060 : 620,
          maxHeight: 820,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Text(_reason ?? error),
                FilledButton(
                  onPressed: saving ? null : () => submit(_pending!),
                  child: const Text('Reintentar el mismo guardado'),
                ),
              ],
              if (saving) const LinearProgressIndicator(),
              Flexible(
                child: AbsorbPointer(
                  absorbing: saving || _pending != null,
                  child: ExerciseForm(
                    title: widget.previous == null
                        ? 'Nuevo ejercicio privado'
                        : 'Revisar ejercicio privado',
                    supportingText: 'Se guarda en tu biblioteca. Para que lo vea un alumno, utiliza el ejercicio en una sesión asignada. Las sesiones ya creadas conservan su versión.',
                    submitLabel: widget.previous == null
                        ? 'Crear ejercicio'
                        : 'Guardar nueva versión',
                    initialDraft:
                        widget.previous?.draft ??
                        (widget.initialVideoUrl == null
                            ? null
                            : ExerciseDraft(
                                name: '',
                                muscleGroups: const [],
                                equipment: const [],
                                difficulty: 'inicial',
                                exerciseType: 'repeticiones',
                                videoUrl: widget.initialVideoUrl,
                              )),
                    initialImageUrl: widget.previous?.imageUrl,
                    fieldKeyPrefix: 'trainer-exercise',
                    onDirtyChanged: markDirty,
                    onSubmit: submit,
                    videoFieldBuilder:
                        widget.videoSource == null &&
                            widget.mediaRepository == null
                        ? null
                        : (controller, onBusyChanged, applyCover) =>
                              ExerciseVideoField(
                                controller: controller,
                                repository:
                                    widget.videoSource ??
                                    widget.mediaRepository!.source(),
                                onPickExisting: widget.mediaRepository == null
                                    ? null
                                    : (context) => showTrainerMediaPicker(
                                        context,
                                        widget.mediaRepository!,
                                      ),
                                onBusyChanged: onBusyChanged,
                                onCoverReady: applyCover,
                                maxVideoBytes: 100 * 1024 * 1024,
                                maxVideoDurationSeconds: 180,
                              ),
                  ),
                ),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
