import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_mutation_queue.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('conserva las operaciones pendientes entre instancias', () async {
    final preferences = await SharedPreferences.getInstance();
    final queue = SharedPreferencesWorkoutMutationQueue(preferences);
    final mutation = PendingWorkoutMutation(
      operationId: 'operation-1',
      type: WorkoutMutationType.completeSet,
      resourceId: 'result-1',
      values: const {'p_actual_reps': 8, 'p_actual_load_kg': 20.5},
      createdAt: DateTime.utc(2026, 9, 21, 10),
    );

    await queue.enqueue(mutation);
    final restored = await SharedPreferencesWorkoutMutationQueue(
      preferences,
    ).readAll();

    expect(restored, [mutation]);
  });

  test('no duplica una operación y permite retirarla al sincronizar', () async {
    final preferences = await SharedPreferences.getInstance();
    final queue = SharedPreferencesWorkoutMutationQueue(preferences);
    final mutation = PendingWorkoutMutation(
      operationId: 'operation-1',
      type: WorkoutMutationType.skipSet,
      resourceId: 'result-1',
      values: const {},
      createdAt: DateTime.utc(2026, 9, 21, 10),
    );

    await queue.enqueue(mutation);
    await queue.enqueue(mutation);
    expect(await queue.readAll(), hasLength(1));

    await queue.remove(mutation.operationId);
    expect(await queue.readAll(), isEmpty);
  });
}
