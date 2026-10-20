import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

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
  });

  final AdminProgram? program;
  final AdminWorkoutRepository repository;
  final WorkoutTemplate? originalTemplate;
  final String? revisionId;
  final bool warmup;
  final Future<String> Function(CreatePersonalWorkoutInput)? saveInput;
  final bool returnSavedId;
  final bool initialShowInLibrary;

  @override
  State<AdminWorkoutEditorPage> createState() => _AdminWorkoutEditorPageState();
}

class _AdminWorkoutEditorPageState extends State<AdminWorkoutEditorPage> {
  late bool _showInLibrary = widget.initialShowInLibrary;

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
      onSave: _save,
      onSaved: (id) => context.pop<Object>(widget.returnSavedId ? id : true),
      originalTemplate: widget.originalTemplate,
      warmup: widget.warmup,
      title: widget.warmup ? 'Crear calentamiento' : sessionTitle,
      wideTitle: widget.warmup
          ? 'Crear calentamiento'
          : '$sessionTitle · ${widget.program?.name ?? 'EntrenaOP'}',
      heading: widget.warmup
          ? 'Calentamiento reutilizable'
          : widget.program == null
          ? 'Sesión en borrador'
          : 'Sesión del programa en borrador',
      instructions: widget.warmup
          ? 'Guarda una versión para adjuntarla a las sesiones. El deportista podrá omitirla.'
          : widget.program == null
          ? 'Al publicarla podrás usarla en programas. La opción Mostrar en Sesiones de EntrenaOP decide si también aparece como sesión suelta.'
          : 'Se vincula al programa, no a la biblioteca general. Publicar no la asigna a ningún alumno.',
      saveLabel: widget.warmup
          ? 'Guardar calentamiento'
          : widget.revisionId == null
          ? 'Guardar borrador'
          : 'Guardar revisión como borrador',
      emptyCatalogMessage: 'No hay ejercicios públicos cargados.',
      additionalStateStamp: _showInLibrary.toString(),
      additionalFields:
          !widget.warmup &&
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
