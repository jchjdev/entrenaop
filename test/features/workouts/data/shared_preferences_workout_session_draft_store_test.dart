import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_session_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final draft = WorkoutSessionSetDraft(
    result: const WorkoutSetResultInput(
      resultId: 'set',
      actualReps: 8,
      actualRir: 0,
    ),
    endedAt: DateTime.utc(2026, 10, 15),
    fields: const {'reps': '8', 'duration': '00:'},
    confirmed: false,
  );
  test(
    'recupera un resultado pendiente y conserva el texto sin reinterpretarlo',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesWorkoutSessionDraftStore(
        preferences,
        userId: 'A',
      );
      await store.write('session', {'set': draft});
      final restored = await SharedPreferencesWorkoutSessionDraftStore(
        preferences,
        userId: 'A',
      ).read('session');
      expect(restored['set'], draft);
      expect(restored['set']!.confirmed, false);
      expect(restored['set']!.fields['duration'], '00:');
    },
  );
  test('cuentas y sesiones tienen borradores independientes', () async {
    final preferences = await SharedPreferences.getInstance();
    final a = SharedPreferencesWorkoutSessionDraftStore(
      preferences,
      userId: 'A',
    );
    final b = SharedPreferencesWorkoutSessionDraftStore(
      preferences,
      userId: 'B',
    );
    await a.write('session', {'set': draft});
    expect(await b.read('session'), isEmpty);
    expect(await a.read('other-session'), isEmpty);
    await b.clear('session');
    expect((await a.read('session'))['set'], draft);
    await a.clear('session');
    expect(await a.read('session'), isEmpty);
  });
  test('sin identidad no se leen ni sobrescriben borradores', () async {
    final store = SharedPreferencesWorkoutSessionDraftStore(
      await SharedPreferences.getInstance(),
      userId: null,
    );
    await expectLater(store.read('session'), throwsStateError);
    expect(() => store.write('session', {}), throwsStateError);
  });
  test('un contenido ilegible no desaparece al intentar recuperarlo', () async {
    final preferences = await SharedPreferences.getInstance();
    const key = 'workout.session-draft.v1:A:session';
    await preferences.setString(key, 'incompleto');
    final store = SharedPreferencesWorkoutSessionDraftStore(
      preferences,
      userId: 'A',
    );
    await expectLater(store.read('session'), throwsFormatException);
    expect(preferences.getString(key), 'incompleto');
  });
  test(
    'no confirma métricas ausentes, no finitas o esfuerzo fuera de escala',
    () {
      const set = WorkoutExecutionSet(
        id: 'set',
        blockOrder: 0,
        blockName: 'Principal',
        blockFormat: WorkoutBlockFormat.straightSets,
        itemOrder: 0,
        exerciseId: 'exercise',
        exerciseName: 'Dominada',
        setOrder: 0,
        targetReps: 10,
        targetLoadKg: 5,
        restAfterSeconds: 45,
        status: WorkoutSetStatus.pending,
      );
      expect(
        WorkoutSessionSetDraft(
          result: const WorkoutSetResultInput(resultId: 'set'),
        ).canConfirm(set),
        false,
      );
      expect(
        WorkoutSessionSetDraft(
          result: const WorkoutSetResultInput(
            resultId: 'set',
            actualReps: 8,
            actualLoadKg: double.nan,
          ),
        ).canConfirm(set),
        false,
      );
      expect(
        WorkoutSessionSetDraft(
          result: const WorkoutSetResultInput(
            resultId: 'set',
            actualReps: 8,
            actualLoadKg: 0,
            actualRir: 11,
          ),
        ).canConfirm(set),
        false,
      );
      expect(
        WorkoutSessionSetDraft(
          result: const WorkoutSetResultInput(
            resultId: 'set',
            actualReps: 8,
            actualLoadKg: 0,
            actualRir: 0,
          ),
        ).canConfirm(set),
        true,
      );
    },
  );
}
