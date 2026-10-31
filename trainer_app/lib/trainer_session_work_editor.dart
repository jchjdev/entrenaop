import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/editor_work_checkpoint.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_workout_repository.dart';

Map<String, dynamic> trainerSessionWorkOrigin({
  String? baseId,
  bool duplicate = false,
  String? parentWorkId,
  String? phaseId,
  String? positionId,
  String? assignmentId,
  int? planningRevision,
}) => {
  'baseId': baseId,
  'programId': null,
  'parentWorkId': parentWorkId,
  'phaseId': phaseId,
  'positionId': positionId,
  'duplicate': duplicate,
  if (assignmentId != null) ...{
    'assignmentId': assignmentId,
    'planningRevision': planningRevision,
  },
};

/// Recupera primero el trabajo íntegro. Fallar nunca monta un formulario vacío.
class TrainerSessionWorkEditor extends StatefulWidget {
  const TrainerSessionWorkEditor({
    super.key,
    required this.workId,
    required this.repository,
    required this.workouts,
    required this.onSaved,
    this.initialOrigin,
    this.onCreateExercise,
    this.exercisePreferences,
    this.embedded = false,
    this.heading,
    this.instructions,
    this.saveLabel,
  });

  final String workId;
  final WorkoutEditorWorkRepository repository;
  final TrainerWorkoutRepository workouts;
  final Future<void> Function(String) onSaved;
  final Map<String, dynamic>? initialOrigin;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  final bool embedded;
  final String? heading, instructions, saveLabel;

  @override
  State<TrainerSessionWorkEditor> createState() =>
      _TrainerSessionWorkEditorState();
}

class _TrainerSessionWorkEditorState extends State<TrainerSessionWorkEditor> {
  late Future<(WorkoutEditorWork, WorkoutTemplate?)> _data = _load();

  @override
  void didUpdateWidget(covariant TrainerSessionWorkEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workId != oldWidget.workId ||
        widget.repository != oldWidget.repository) {
      _data = _load();
    }
  }

  Future<(WorkoutEditorWork, WorkoutTemplate?)> _load() async {
    final loaded = await widget.repository.load(widget.workId);
    if (loaded == null && widget.initialOrigin == null) {
      throw StateError('Trabajo no disponible.');
    }
    final work =
        loaded ??
        WorkoutEditorWork(id: widget.workId, origin: widget.initialOrigin!);
    if (work.id != widget.workId || work.discarded) {
      throw StateError('Trabajo cerrado o incompatible.');
    }
    // La base persistida manda sobre una query antigua del enlace inicial.
    final origin = work.origin;
    if (canonicalEditorState(origin) !=
        canonicalEditorState(
          trainerSessionWorkOrigin(
            baseId: origin['baseId'] as String?,
            duplicate: origin['duplicate'] as bool,
            parentWorkId: origin['parentWorkId'] as String?,
            phaseId: origin['phaseId'] as String?,
            positionId: origin['positionId'] as String?,
            assignmentId: origin['assignmentId'] as String?,
            planningRevision: origin['planningRevision'] as int?,
          ),
        )) {
      throw const FormatException('Contexto profesional incompatible.');
    }
    WorkoutTemplate? original;
    final base = origin['baseId'] as String?;
    if (base != null && work.state.isEmpty) {
      original = await widget.workouts.template(base);
      if (original == null) throw StateError('Sesión de origen no disponible.');
      if (origin['duplicate'] == true) {
        original = WorkoutTemplate(
          id: original.id,
          name: '${original.name.characters.take(110)} · copia',
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
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(WorkoutEditorWork, WorkoutTemplate?)>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.hasError) {
        final content = snapshot.hasError
            ? Padding(
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
              )
            : const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
        if (widget.embedded) return content;
        return Scaffold(
          appBar: AppBar(title: const Text('Sesión privada')),
          body: Center(child: content),
        );
      }
      final (work, original) = snapshot.data!;
      final revision =
          work.origin['baseId'] != null && work.origin['duplicate'] != true;
      return WorkoutEditorPage(
        loadWarmups: widget.workouts.warmups,
        embedded: widget.embedded,
        key: ValueKey('trainer-session-work-${work.id}'),
        workBinding: _TrainerSessionWorkBinding(
          work: work,
          repository: widget.repository,
          onSaved: (id) async {
            if (!mounted) throw StateError('La edición se ha cerrado.');
            await widget.onSaved(id);
          },
        ),
        originalTemplate: original,
        loadExercises: () => widget.workouts.exercises(
          retainedIds: {
            for (final block in original?.blocks ?? <WorkoutBlock>[])
              for (final item in block.items) item.exerciseId,
            for (final block in work.state['editor']?['blocks'] as List? ?? [])
              for (final item in block['exercises'] as List? ?? [])
                if (item['exerciseId'] is String) item['exerciseId'] as String,
          },
        ),
        onCreateExercise: widget.onCreateExercise,
        exercisePreferences: widget.exercisePreferences,
        // Con binding, el editor confirma la intención durable por su RPC.
        // El puerto legacy no debe crear una segunda versión por accidente.
        onSave: (_) =>
            throw StateError('Confirma primero el trabajo guardado.'),
        onSaved: (_) {},
        title: revision ? 'Revisar sesión privada' : 'Crear sesión privada',
        heading:
            widget.heading ??
            (work.origin['parentWorkId'] != null
                ? 'Sesión del programa privado'
                : 'Biblioteca del preparador'),
        instructions:
            widget.instructions ??
            (revision
                ? 'Se guarda una nueva versión. Las pautas anteriores conservan la receta que recibieron.'
                : 'Guárdala en tu biblioteca y después asígnala a tus alumnos.'),
        saveLabel:
            widget.saveLabel ??
            (revision ? 'Guardar nueva versión' : 'Guardar sesión privada'),
      );
    },
  );
}

class _TrainerSessionWorkBinding extends WorkoutEditorWorkBinding {
  _TrainerSessionWorkBinding({
    required this.work,
    required this.repository,
    required this.onSaved,
  });

  @override
  final WorkoutEditorWork work;
  @override
  final WorkoutEditorWorkRepository repository;
  final Future<void> Function(String) onSaved;

  @override
  Map<String, dynamic> captureContext() => {};
  @override
  void restoreContext(Map<String, dynamic> context) {
    if (context.isNotEmpty) {
      throw const FormatException('Contexto profesional incompatible.');
    }
  }

  @override
  Future<void> acknowledge(String resultId) => onSaved(resultId);
  @override
  bool definitiveError(Object error) =>
      error is WorkoutWorkConflict ||
      error is PostgrestException &&
          {'22023', '23503', '42501', '40001'}.contains(error.code);
}
