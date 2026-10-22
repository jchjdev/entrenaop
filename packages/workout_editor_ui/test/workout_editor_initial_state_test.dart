import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';

void main() {
  test(
    'recupera carrera agrupada sin perder rangos, medidas o recuperación final',
    () {
      const work = WorkoutSetDraft(
        targetType: WorkoutTargetType.distance,
        targetValue: 1000,
        restAfterSeconds: 0,
        targetPaceMinSecondsPerKm: 240,
        targetPaceMaxSecondsPerKm: 300,
        recoveryType: RunningRecoveryType.walking,
        recoveryDurationSeconds: 30,
      );
      const timed = WorkoutSetDraft(
        targetType: WorkoutTargetType.duration,
        targetValue: 600,
        restAfterSeconds: 0,
      );
      const input = CreatePersonalWorkoutInput(
        name: 'Carrera recuperada',
        description: '',
        estimatedDurationMinutes: 20,
        blocks: [
          WorkoutBlockDraft(
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: runningExerciseId,
                sets: [work, work, timed],
              ),
            ],
          ),
        ],
      );
      final state = workoutEditorStateFromInput(input);
      expect((state.value['segments'] as List).length, 2);
      expect(state.value['segments'][0]['countText'], '2');
      expect(projectWorkoutEditorSnapshot(state), input);
    },
  );

  test(
    'recupera excepciones y retirada de carga/RIR sin herencia accidental',
    () {
      const input = CreatePersonalWorkoutInput(
        name: 'Fuerza recuperada',
        description: '',
        blocks: [
          WorkoutBlockDraft(
            name: 'Principal',
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: 'exercise',
                sets: [
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.repetitions,
                    targetValue: 8,
                    restAfterSeconds: 90,
                    targetLoadKg: 20,
                    targetRir: 2,
                  ),
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.repetitions,
                    targetValue: 10,
                    restAfterSeconds: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      expect(
        projectWorkoutEditorSnapshot(workoutEditorStateFromInput(input)),
        input,
      );
    },
  );

  for (final format in [
    WorkoutBlockFormat.straightSets,
    WorkoutBlockFormat.superset,
    WorkoutBlockFormat.circuit,
    WorkoutBlockFormat.intervals,
    WorkoutBlockFormat.emom,
    WorkoutBlockFormat.amrap,
    WorkoutBlockFormat.tabata,
  ]) {
    test('recupera $format conservando su receta y validación', () {
      final tabata = format == WorkoutBlockFormat.tabata;
      final amrap = format == WorkoutBlockFormat.amrap;
      final rounds = tabata
          ? 8
          : amrap || format == WorkoutBlockFormat.straightSets
          ? 1
          : 3;
      final count =
          format == WorkoutBlockFormat.superset ||
              format == WorkoutBlockFormat.circuit
          ? 2
          : tabata
          ? 8
          : 1;
      final input = CreatePersonalWorkoutInput(
        name: 'Sesión recuperada',
        description: '',
        estimatedDurationMinutes: 30,
        blocks: [
          WorkoutBlockDraft(
            name: 'Principal',
            format: format,
            rounds: rounds,
            timeCapSeconds: amrap ? 600 : null,
            restAfterSeconds: tabata
                ? 10
                : format == WorkoutBlockFormat.emom
                ? 60
                : 0,
            exercises: List.generate(
              count,
              (index) => WorkoutExerciseDraft(
                exerciseId: 'exercise-$index',
                sets: List.generate(
                  tabata || amrap ? 1 : rounds,
                  (_) => WorkoutSetDraft(
                    targetType: tabata
                        ? WorkoutTargetType.duration
                        : WorkoutTargetType.repetitions,
                    targetValue: tabata ? 20 : 8,
                    restAfterSeconds: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      final restored = projectWorkoutEditorSnapshot(
        workoutEditorStateFromInput(input),
      );
      expect(restored, input);
      expect(() => validateWorkoutDraft(restored), returnsNormally);
    });
  }

  test(
    'los cuarenta tramos se cuentan expandidos entre todas las tarjetas',
    () {
      const set = WorkoutSetDraft(
        targetType: WorkoutTargetType.duration,
        targetValue: 60,
        restAfterSeconds: 0,
      );
      const input = CreatePersonalWorkoutInput(
        name: 'Límite carrera',
        blocks: [
          WorkoutBlockDraft(
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: runningExerciseId,
                sets: [
                  set,
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.duration,
                    targetValue: 61,
                    restAfterSeconds: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final state = workoutEditorStateFromInput(input).value;
      state['segments'][0]['countText'] = '21';
      state['segments'][1]['countText'] = '20';
      expect(
        () => projectWorkoutEditorSnapshot(WorkoutEditorSnapshot(state)),
        throwsFormatException,
      );
    },
  );
}
