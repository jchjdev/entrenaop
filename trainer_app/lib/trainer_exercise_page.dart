import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/exercise_video_field.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

import 'trainer_exercise_repository.dart';
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
          muscleGroups: draft.muscleGroups,
          equipment: draft.equipment,
        );
      },
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
  });
  final TrainerExerciseRepository repository;
  final TrainerRepository access;
  final ExerciseVideoSource? videoSource;
  final TrainerMediaRepository? mediaRepository;
  @override
  State<TrainerExercisePage> createState() => _TrainerExercisePageState();
}

class _TrainerExercisePageState extends State<TrainerExercisePage> {
  List<TrainerExercise> _items = [];
  TrainerExerciseUsage? _usage;
  bool _busy = true, _enabled = false;
  String _query = '';
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
      final access = await widget.access.access();
      final usage = await widget.repository.usage();
      final items = await widget.repository.list();
      if (mounted) {
        setState(() {
          _items = items.where((e) => e.current).toList();
          _usage = usage;
          _enabled = access.effective && usage.exercises < usage.exerciseLimit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerExerciseError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis ejercicios privados'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
              tilePadding: EdgeInsets.zero,
              title: Text('Límites y conservación'),
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Las versiones anteriores conservan el historial y cuentan en el límite. Cada imagen ocupa como máximo 500 KB; las reservas de subidas también cuentan. Puedes enlazar un vídeo HTTPS del proveedor que ya utilices o subir un archivo privado cuando la subida esté disponible. Los enlaces externos dependen de la disponibilidad y privacidad de ese proveedor.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || !_enabled ? null : _edit,
              icon: const Icon(Icons.add),
              label: const Text('Crear ejercicio privado'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar en mis ejercicios',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (!_busy && _items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no has creado ejercicios propios.'),
              ),
            for (final exercise in _items.where(
              (e) => e.draft.name.toLowerCase().contains(_query),
            ))
              Card(
                child: ListTile(
                  title: Text(exercise.draft.name),
                  subtitle: Text(
                    'Versión ${exercise.version} · ${exercise.draft.muscleGroups.join(', ')}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: !_enabled || _busy ? null : () => _edit(exercise),
                ),
              ),
          ],
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) =>
      RetainedSaveDialog<ExerciseFormSubmission<ExerciseDraft>>(
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
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
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
                                    onPickExisting:
                                        widget.mediaRepository == null
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
