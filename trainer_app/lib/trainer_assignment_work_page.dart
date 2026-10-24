import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/guided_program_work.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_operations_repository.dart';
import 'trainer_session_work_editor.dart';
import 'trainer_workout_repository.dart';

class TrainerAssignmentWorkPage extends StatefulWidget {
  const TrainerAssignmentWorkPage({
    super.key,
    required this.operations,
    required this.workouts,
    required this.assignmentId,
    required this.repository,
    this.workId,
    this.onCreateExercise,
    this.exercisePreferences,
  });
  final TrainerOperationsRepository operations;
  final TrainerWorkoutRepository workouts;
  final String assignmentId;
  final String? workId;
  final WorkoutEditorWorkRepository Function(Future<void> Function(bool))
  repository;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  @override
  State<TrainerAssignmentWorkPage> createState() =>
      _TrainerAssignmentWorkPageState();
}

class _TrainerAssignmentWorkPageState extends State<TrainerAssignmentWorkPage> {
  late final _repository = widget.repository(_review);
  late final _id = widget.workId ?? newGuidedWorkId();
  late Future<(Map<String, dynamic>, String)> _data = _load();

  Future<(Map<String, dynamic>, String)> _load() async {
    final work = await _repository.load(_id);
    if (work != null && work.origin['assignmentId'] != widget.assignmentId) {
      throw const FormatException('El trabajo pertenece a otra pauta.');
    }
    // La ruta reserva el UUID antes del primer autosave. Un fallo de lectura
    // lanza una excepción; solo null permite iniciar un trabajo todavía nuevo.
    final detail = await widget.operations.assignment(widget.assignmentId);
    if (work != null) return (work.origin, detail.clientName);
    if (detail.assignment.status != 'planned' ||
        detail.assignment.executionId != null) {
      throw StateError('Solo se adapta una pauta pendiente sin iniciar.');
    }
    return (
      trainerSessionWorkOrigin(
        baseId: detail.assignment.templateId,
        assignmentId: widget.assignmentId,
        planningRevision: detail.assignment.revision,
      ),
      detail.clientName,
    );
  }

  Future<void> _review(bool coincidence) async {
    if (!mounted) throw StateError('La edición se ha cerrado.');
    if (!coincidence) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revisar coincidencia'),
        content: const Text(
          'Ese día hay otra sesión en su agenda. Esta adaptación conserva ambas. Confirma que quieres continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar adaptación'),
          ),
        ],
      ),
    );
    if (!mounted || yes != true) {
      throw StateError('Adaptación sin enviar. El borrador se conserva.');
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(Map<String, dynamic>, String)>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Adaptar pauta')),
              body: Center(
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No se pudo recuperar la adaptación. El trabajo guardado se conserva.',
                          ),
                          TextButton(
                            onPressed: () => setState(() => _data = _load()),
                            child: const Text('Reintentar recuperación'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final (origin, name) = snapshot.data!;
          return TrainerSessionWorkEditor(
            workId: _id,
            initialOrigin: origin,
            repository: _repository,
            workouts: widget.workouts,
            heading: 'Adaptación de $name',
            instructions: 'El borrador se guarda sin cambiar la pauta. Al confirmar se modifica solo esta entrega; la biblioteca y el resto de alumnos conservan sus versiones.',
            saveLabel: 'Guardar adaptación individual',
            onCreateExercise: widget.onCreateExercise,
            exercisePreferences: widget.exercisePreferences,
            onSaved: (_) async {
              if (mounted) {
                context.canPop() ? context.pop(true) : context.go('/agenda');
              }
            },
          );
        },
      );
}
