import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_amrap_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_amrap_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'recupera la cuenta y campos incompletos por cuenta, sesión y bloque',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesWorkoutAmrapDraftStore(
        preferences,
        userId: 'A',
      );
      const draft = WorkoutAmrapDraft(
        rounds: '5',
        hasPartial: true,
        partialItemOrder: 2,
        partialReps: '',
      );
      await Future.wait([
        store.write('session', {0: const WorkoutAmrapDraft(rounds: '4')}),
        store.write('session', {
          0: draft,
          2: const WorkoutAmrapDraft(rounds: '1'),
        }),
      ]);
      final restored = SharedPreferencesWorkoutAmrapDraftStore(
        preferences,
        userId: 'A',
      );
      expect((await restored.read('session'))[0], draft);
      expect((await restored.read('session'))[2]?.rounds, '1');
      expect(await restored.read('other-session'), isEmpty);
      final other = SharedPreferencesWorkoutAmrapDraftStore(
        preferences,
        userId: 'B',
      );
      expect(await other.read('session'), isEmpty);
      await other.clear('session');
      expect((await restored.read('session'))[0], draft);
      await store.clear('session');
      expect(await restored.read('session'), isEmpty);
    },
  );
  test(
    'un borrador roto se conserva y sin cuenta no se lee ni se escribe',
    () async {
      final preferences = await SharedPreferences.getInstance();
      const key = 'workout.amrap-draft.v1:A:s';
      await preferences.setString(key, 'roto');
      final store = SharedPreferencesWorkoutAmrapDraftStore(
        preferences,
        userId: 'A',
      );
      await expectLater(store.read('s'), throwsFormatException);
      expect(preferences.getString(key), 'roto');
      final anonymous = SharedPreferencesWorkoutAmrapDraftStore(
        preferences,
        userId: null,
      );
      await expectLater(anonymous.read('s'), throwsStateError);
      expect(() => anonymous.write('s', {}), throwsStateError);
    },
  );
}
