import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_session_set_draft.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/services/running_execution_assessment.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_execution_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const metadata = RunningStepMetadata(
  kind: RunningStepKind.warmup,
  completion: RunningStepCompletion.manual,
);
WorkoutExecutionSet execution(RunningStepKind kind, double distance) =>
    WorkoutExecutionSet(
      id: 'result',
      blockOrder: 0,
      blockName: 'Carrera',
      blockFormat: WorkoutBlockFormat.running,
      itemOrder: 0,
      exerciseId: runningExerciseId,
      exerciseName: 'Carrera',
      setOrder: 0,
      restAfterSeconds: 0,
      status: WorkoutSetStatus.completed,
      runningStep: RunningStepMetadata(
        kind: kind,
        completion: RunningStepCompletion.manual,
      ),
      actualDurationSeconds: 120,
      actualDistanceMeters: distance,
    );
void main() {
  test('el borrador personal conserva V2 por cuenta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkoutEditorDraftStore(
      prefs,
      userId: 'owner',
    );
    final snapshot = WorkoutEditorDraftSnapshot(
      savedAt: DateTime.utc(2026, 10, 22),
      input: const CreatePersonalWorkoutInput(
        name: 'Calentamiento manual',
        blocks: [
          WorkoutBlockDraft(
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: runningExerciseId,
                sets: [
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.manual,
                    targetValue: 0,
                    restAfterSeconds: 0,
                    runningStep: metadata,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await store.write('new', snapshot);
    expect(await store.read('new'), snapshot);
    expect(
      await SharedPreferencesWorkoutEditorDraftStore(
        prefs,
        userId: 'other',
      ).read('new'),
      isNull,
    );
  });
  test(
    'ejecución y copia del resultado conservan el tipo y el avance manual',
    () {
      final set = execution(RunningStepKind.warmup, 800);
      expect(workoutTargetLabel(set), 'Hasta avanzar al siguiente paso');
      expect(workoutPositionLabel(set), 'Calentamiento 1');
      expect(
        set.copyWith(status: WorkoutSetStatus.pending).runningStep,
        set.runningStep,
      );
      expect(
        assessRunningExecution([set]),
        RunningExecutionAssessment.onTarget,
      );
    },
  );
  test(
    'un descanso explícito permite cero metros sin inventar desplazamiento',
    () {
      final rest = execution(RunningStepKind.rest, 0);
      final result = WorkoutSetResultInput(
        resultId: rest.id,
        actualDurationSeconds: 120,
        actualDistanceMeters: 0,
      );
      expect(WorkoutSessionSetDraft(result: result).canConfirm(rest), isTrue);
      expect(
        assessRunningExecution([rest]),
        RunningExecutionAssessment.onTarget,
      );
      expect(
        WorkoutSessionSetDraft(result: result)
            .canConfirm(execution(RunningStepKind.run, 0)),
        isFalse,
      );
    },
  );
}
