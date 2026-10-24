import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/guided_program_work.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_program_pages.dart';
import 'trainer_program_repository.dart';
import 'trainer_workout_repository.dart';

/// La ruta recibe un UUID ya creado por su lanzador. `base` solo es semilla
/// mientras no existe checkpoint; nunca reemplaza la base guardada en servidor.
class TrainerProgramWorkPage extends StatefulWidget {
  const TrainerProgramWorkPage({
    super.key,
    required this.repository,
    required this.workouts,
    required this.workRepository,
    required this.workId,
    this.initialBaseProgramId,
    this.onCreateExercise,
    this.exercisePreferences,
    this.sessionWorkRepository,
  });
  final TrainerProgramRepository repository;
  final TrainerWorkoutRepository workouts;
  final GuidedWorkRepository workRepository;
  final WorkoutEditorWorkRepository? sessionWorkRepository;
  final String workId;
  final String? initialBaseProgramId;
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;

  @override
  State<TrainerProgramWorkPage> createState() => _TrainerProgramWorkPageState();
}

class _TrainerProgramWorkPageState extends State<TrainerProgramWorkPage> {
  late Future<GuidedWork> _work = _load();
  int _generation = 0;

  @override
  void didUpdateWidget(covariant TrainerProgramWorkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId ||
        oldWidget.workRepository != widget.workRepository ||
        oldWidget.repository != widget.repository) {
      _work = _load();
    }
  }

  Future<GuidedWork> _load() async {
    final generation = ++_generation;
    final repository = widget.workRepository;
    final programs = widget.repository;
    final id = widget.workId;
    final base = widget.initialBaseProgramId;
    void current() {
      if (!mounted || generation != _generation) {
        throw StateError('La cuenta o el trabajo han cambiado.');
      }
    }

    current();
    final work = await repository.load(id);
    current();
    if (work != null) {
      if (work.id != id) throw const FormatException('Trabajo no disponible.');
      return work;
    }
    // Recargar antes del primer guardado conserva la revisión elegida en la
    // URL. En el primer CAS el servidor valida propiedad/publicación y la fija.
    if (base != null) {
      final original = await programs.program(base);
      current();
      if (original.id != base || original.status != 'published') {
        throw const FormatException(
          'El programa de origen ya no está publicado. Vuelve a tu biblioteca.',
        );
      }
    }
    return GuidedWork(id: id, state: const {}, baseProgramId: base);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GuidedWork>(
    future: _work,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final work = snapshot.data;
      if (snapshot.hasError || work == null) {
        return _unavailable(
          snapshot.error is FormatException
              ? (snapshot.error as FormatException).message.toString()
              : 'No se pudo cargar el trabajo.',
          retry: true,
        );
      }
      if (work.permanentlyDeleted) {
        return _unavailable('Este trabajo se ha eliminado definitivamente.');
      }
      if (work.discarded) {
        return _unavailable('Este trabajo está descartado.');
      }
      final finalized = work.finalizedProgramId;
      if (finalized != null) {
        // Es el recibo de ESTA finalización; no se busca otra versión vigente.
        return TrainerProgramDetailPage(
          repository: widget.repository,
          workouts: widget.workouts,
          programId: finalized,
        );
      }
      return TrainerProgramEditorPage(
        key: ValueKey('${work.id}:${work.revision}'),
        repository: widget.repository,
        workouts: widget.workouts,
        programId: work.baseProgramId,
        workRepository: widget.workRepository,
        work: work,
        onCreateExercise: widget.onCreateExercise,
        exercisePreferences: widget.exercisePreferences,
        sessionWorkRepository: widget.sessionWorkRepository,
      );
    },
  );

  Widget _unavailable(String message, {bool retry = false}) => Scaffold(
    appBar: AppBar(title: const Text('Trabajo de programa')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            if (retry)
              TextButton(
                onPressed: () {
                  final next = _load();
                  setState(() {
                    _work = next;
                  });
                },
                child: const Text('Reintentar'),
              ),
            TextButton(
              onPressed: () => context.go('/programs'),
              child: const Text('Volver a mis programas'),
            ),
          ],
        ),
      ),
    ),
  );
}
