import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda, recupera y elimina una instantánea del temporizador', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesWorkoutTimerStore(preferences);
    final snapshot = WorkoutTimerSnapshot(
      phase: WorkoutTimerPhase.paused,
      targetSeconds: 30,
      preparationSeconds: 3,
      phaseStartedAt: DateTime.utc(2026, 9, 20, 20),
      elapsedBeforeRun: const Duration(milliseconds: 12500),
    );

    await store.write('execution:set', snapshot);

    expect(await store.read('execution:set'), snapshot);
    await store.clear('execution:set');
    expect(await store.read('execution:set'), isNull);
  });
}
