import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restaura toda la estructura de un borrador', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkoutEditorDraftStore(preferences);
    final snapshot = WorkoutEditorDraftSnapshot(
      savedAt: DateTime.utc(2026, 9, 21, 20, 30),
      input: const CreatePersonalWorkoutInput(
        name: 'Fuerza de empuje',
        description: 'Borrador local',
        estimatedDurationMinutes: 45,
        blocks: [
          WorkoutBlockDraft(
            name: 'Principal',
            format: WorkoutBlockFormat.circuit,
            rounds: 3,
            restAfterSeconds: 90,
            exercises: [
              WorkoutExerciseDraft(
                exerciseId: 'exercise-1',
                sets: [
                  WorkoutSetDraft(
                    targetType: WorkoutTargetType.repetitions,
                    targetValue: 10,
                    restAfterSeconds: 15,
                    targetLoadKg: 20,
                    targetRir: 2,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await store.write('new', snapshot);
    final restored = await SharedPreferencesWorkoutEditorDraftStore(
      preferences,
    ).read('new');

    expect(restored, snapshot);
  });

  test('elimina un borrador guardado', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkoutEditorDraftStore(preferences);
    await store.write(
      'template-1',
      WorkoutEditorDraftSnapshot(
        savedAt: DateTime.utc(2026),
        input: const CreatePersonalWorkoutInput(name: '', blocks: []),
      ),
    );

    await store.clear('template-1');

    expect(await store.read('template-1'), isNull);
  });
}
