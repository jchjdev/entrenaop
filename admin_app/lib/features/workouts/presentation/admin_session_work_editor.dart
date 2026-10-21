import 'package:flutter/material.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';
import 'package:workout_editor_ui/editor_work_checkpoint.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';

import '../data/admin_workout_repository.dart';
import '../../exercises/data/admin_exercise_repository.dart';
import '../../exercises/data/admin_exercise_video_repository.dart';
import 'admin_workout_editor_page.dart';

/// Carga el trabajo antes de montar el editor; un fallo nunca abre un formulario vacío.
class AdminSessionWorkEditor extends StatefulWidget {
  const AdminSessionWorkEditor({
    super.key,
    required this.workId,
    required this.repository,
    required this.workouts,
    required this.onSaved,
    this.origin,
    this.embedded = false,
    this.programName,
    this.initialShowInLibrary = true,
    this.exerciseRepository,
    this.exerciseVideos,
    this.exercisePreferences,
  });
  final String workId;
  final WorkoutEditorWorkRepository repository;
  final AdminWorkoutRepository workouts;
  final Map<String, dynamic>? origin;
  final bool embedded;
  final String? programName;
  final bool initialShowInLibrary;
  final Future<void> Function(String) onSaved;
  final AdminExerciseRepository? exerciseRepository;
  final AdminExerciseVideoRepository? exerciseVideos;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  State<AdminSessionWorkEditor> createState() => _AdminSessionWorkEditorState();
}

class _AdminSessionWorkEditorState extends State<AdminSessionWorkEditor> {
  late Future<(WorkoutEditorWork, WorkoutTemplate?)> _data = _load();
  Future<(WorkoutEditorWork, WorkoutTemplate?)> _load() async {
    final loaded = await widget.repository.load(widget.workId);
    if (loaded == null && widget.origin == null) {
      throw StateError('Trabajo no disponible');
    }
    final work =
        loaded ?? WorkoutEditorWork(id: widget.workId, origin: widget.origin!);
    if (widget.origin != null &&
        canonicalEditorState(work.origin) !=
            canonicalEditorState(widget.origin!)) {
      throw StateError('El destino no coincide');
    }
    if (work.discarded) throw StateError('Trabajo descartado');
    WorkoutTemplate? original;
    final base = work.origin['baseId'] as String?;
    if (base != null && work.state.isEmpty) {
      original = await widget.workouts.getTemplateById(base);
      if (original == null) throw StateError('Origen no disponible');
      if (work.origin['duplicate'] == true) {
        original = WorkoutTemplate(
          id: original.id,
          name: '${original.name.characters.take(65)} · copia',
          description: original.description,
          estimatedDurationMinutes: original.estimatedDurationMinutes,
          version: 1,
          blocks: original.blocks,
        );
      }
    }
    return (work, original);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(WorkoutEditorWork, WorkoutTemplate?)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudo recuperar la sesión. El trabajo guardado se conserva.',
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _data = _load();
                    }),
                    child: const Text('Reintentar recuperación'),
                  ),
                ],
              ),
            );
          }
          final (work, original) = snapshot.data!;
          return AdminWorkoutEditorPage(
            program: null,
            repository: widget.workouts,
            originalTemplate: original,
            revisionId: work.origin['duplicate'] == true
                ? null
                : work.origin['baseId'] as String?,
            initialShowInLibrary:
                work.origin['parentWorkId'] == null &&
                work.origin['programId'] == null &&
                widget.initialShowInLibrary,
            embedded: widget.embedded,
            programName: widget.programName,
            exerciseRepository: widget.exerciseRepository,
            exerciseVideos: widget.exerciseVideos,
            exercisePreferences: widget.exercisePreferences,
            work: work,
            workRepository: widget.repository,
            onRecoveredSaved: widget.onSaved,
          );
        },
      );
}
