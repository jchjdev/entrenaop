import 'package:workout_editor_ui/workout_editor_work.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import '../../exercises/data/admin_exercise_repository.dart';
import '../../exercises/data/admin_exercise_video_repository.dart';
import '../../exercises/presentation/admin_exercise_dialog.dart';

/// Adaptador de autoría oficial. El creador común no conoce estos permisos,
/// el escaparate de EntrenaOP ni las rutas de administración.
class AdminWorkoutEditorPage extends StatefulWidget {
  const AdminWorkoutEditorPage({
    super.key,
    required this.program,
    required this.repository,
    this.originalTemplate,
    this.revisionId,
    this.warmup = false,
    this.saveInput,
    this.returnSavedId = false,
    this.initialShowInLibrary = true,
    this.onSaved,
    this.programName,
    this.embedded = false,
    this.exerciseRepository,
    this.exerciseVideos,
    this.exercisePreferences,
    this.work,
    this.workRepository,
    this.onRecoveredSaved,
  });

  final WorkoutEditorWork? work;
  final WorkoutEditorWorkRepository? workRepository;
  final Future<void> Function(String)? onRecoveredSaved;
  final AdminProgram? program;
  final AdminWorkoutRepository repository;
  final WorkoutTemplate? originalTemplate;
  final String? revisionId;
  final bool warmup;
  final Future<String> Function(CreatePersonalWorkoutInput)? saveInput;
  final bool returnSavedId;
  final bool initialShowInLibrary;
  final ValueChanged<String>? onSaved;
  final String? programName;
  final bool embedded;
  final AdminExerciseRepository? exerciseRepository;
  final AdminExerciseVideoRepository? exerciseVideos;
  final ExerciseCatalogPreferences? exercisePreferences;

  @override
  State<AdminWorkoutEditorPage> createState() => _AdminWorkoutEditorPageState();
}

class _AdminWorkoutEditorPageState extends State<AdminWorkoutEditorPage> {
  late bool _showInLibrary = widget.initialShowInLibrary;
  late final WorkoutEditorWorkBinding? _binding = widget.work == null
      ? null
      : _AdminWorkBinding(
          widget.work!,
          widget.workRepository!,
          () => _AdminSessionContext(_showInLibrary),
          (value) {
            if (_showInLibrary == value.showInLibrary) return;
            _showInLibrary = value.showInLibrary;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          },
          widget.onRecoveredSaved!,
        );

  Future<List<WorkoutEditorExercise>> _loadExercises() async => [
    for (final exercise in await widget.repository.listPublicExercises())
      WorkoutEditorExercise(
        id: exercise.id,
        name: exercise.name,
        muscleGroups: exercise.muscleGroups,
        equipment: exercise.equipment,
        thumbnailUrl: exercise.thumbnailUrl,
      ),
  ];

  Future<String> _save(CreatePersonalWorkoutInput input) {
    if (widget.saveInput case final save?) return save(input);
    if (widget.revisionId case final id?) {
      return widget.repository.revise(id, input);
    }
    return widget.repository.createDraft(
      widget.program?.id,
      input,
      showInLibrary: _showInLibrary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionTitle = widget.revisionId == null
        ? 'Nueva sesión'
        : 'Revisar sesión';
    return WorkoutEditorPage(
      loadExercises: _loadExercises,
      workBinding: _binding,
      exercisePreferences: widget.exercisePreferences,
      onCreateExercise: widget.exerciseRepository == null
          ? null
          : (context) async {
              final created = await showAdminExerciseDialog(
                context,
                repository: widget.exerciseRepository!,
                videos: widget.exerciseVideos,
              );
              return created == null
                  ? null
                  : WorkoutEditorExercise(
                      id: created.id,
                      name: created.name,
                      muscleGroups: created.muscleGroups,
                      equipment: created.equipment,
                      thumbnailUrl: created.imageUrl,
                    );
            },
      onSave: _save,
      onSaved:
          widget.onSaved ??
          (id) => context.pop<Object>(widget.returnSavedId ? id : true),
      embedded: widget.embedded,
      originalTemplate: widget.originalTemplate,
      warmup: widget.warmup,
      title: widget.warmup ? 'Crear calentamiento' : sessionTitle,
      wideTitle: widget.warmup
          ? 'Crear calentamiento'
          : '$sessionTitle · ${widget.program?.name ?? 'EntrenaOP'}',
      heading: widget.programName != null
          ? widget.revisionId == null
                ? 'Nueva sesión'
                : 'Editar sesión'
          : widget.warmup
          ? 'Calentamiento reutilizable'
          : widget.program == null
          ? 'Sesión en borrador'
          : 'Sesión del programa en borrador',
      instructions: widget.programName != null
          ? 'Se guardará en el programa y se publicará con él.'
          : widget.warmup
          ? 'Guarda una versión para adjuntarla a las sesiones. El deportista podrá omitirla.'
          : widget.program == null
          ? 'Al publicarla podrás usarla en programas. La opción Mostrar en Sesiones de EntrenaOP decide si también aparece como sesión suelta.'
          : 'Se vincula al programa, no a la biblioteca general. Publicar no la asigna a ningún alumno.',
      saveLabel: widget.programName != null
          ? 'Guardar en programa'
          : widget.warmup
          ? 'Guardar calentamiento'
          : widget.revisionId == null
          ? 'Guardar borrador'
          : 'Guardar revisión como borrador',
      emptyCatalogMessage: 'No hay ejercicios públicos cargados.',
      additionalStateStamp: _showInLibrary.toString(),
      additionalFields:
          !widget.warmup &&
              widget.programName == null &&
              widget.program == null &&
              widget.revisionId == null &&
              widget.saveInput == null
          ? SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar en Sesiones de EntrenaOP'),
              subtitle: const Text(
                'Permite encontrarla y entrenarla como sesión suelta. Puede reutilizarse en programas en ambos casos.',
              ),
              value: _showInLibrary,
              onChanged: (value) => setState(() => _showInLibrary = value),
            )
          : null,
    );
  }
}

class _AdminSessionContext {
  const _AdminSessionContext(this.showInLibrary);
  final bool showInLibrary;
  Map<String, dynamic> toJson() => {'showInLibrary': showInLibrary};
  factory _AdminSessionContext.fromJson(Map<String, dynamic> json) {
    if (json.length != 1 || json['showInLibrary'] is! bool) {
      throw const FormatException('Contexto incompatible');
    }
    return _AdminSessionContext(json['showInLibrary'] as bool);
  }
}

class _AdminWorkBinding extends WorkoutEditorWorkBinding {
  _AdminWorkBinding(
    this.work,
    this.repository,
    this.capture,
    this.restore,
    this.onSaved,
  );
  @override
  final WorkoutEditorWork work;
  @override
  final WorkoutEditorWorkRepository repository;
  final _AdminSessionContext Function() capture;
  final void Function(_AdminSessionContext) restore;
  final Future<void> Function(String) onSaved;
  @override
  Map<String, dynamic> captureContext() => capture().toJson();
  @override
  void restoreContext(Map<String, dynamic> context) =>
      restore(_AdminSessionContext.fromJson(context));
  @override
  Future<void> acknowledge(String resultId) => onSaved(resultId);
  @override
  bool definitiveError(Object error) =>
      error is PostgrestException && ['22023', '23503'].contains(error.code);
}
