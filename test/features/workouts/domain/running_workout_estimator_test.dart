import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/running_workout_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula distancia por rango de ritmo y suma recuperaciones', () {
    final estimate = estimateRunningWorkout([
      for (var index = 0; index < 4; index++)
        const WorkoutSetDraft(
          targetType: WorkoutTargetType.distance,
          targetValue: 1000,
          restAfterSeconds: 0,
          targetPaceMinSecondsPerKm: 240,
          targetPaceMaxSecondsPerKm: 270,
          recoveryType: RunningRecoveryType.passive,
          recoveryDurationSeconds: 60,
        ),
    ]);

    expect(estimate.minimumSeconds, 1200);
    expect(estimate.maximumSeconds, 1320);
    expect(estimate.estimatedMinutes, 21);
    expect(estimate.isComplete, isTrue);
  });

  test(
    'marca como parcial una distancia sin ritmo y recuperación por metros',
    () {
      final estimate = estimateRunningWorkout(const [
        WorkoutSetDraft(
          targetType: WorkoutTargetType.duration,
          targetValue: 600,
          restAfterSeconds: 0,
          recoveryType: RunningRecoveryType.jogging,
          recoveryDistanceMeters: 200,
        ),
        WorkoutSetDraft(
          targetType: WorkoutTargetType.distance,
          targetValue: 1000,
          restAfterSeconds: 0,
        ),
      ]);

      expect(estimate.minimumSeconds, 600);
      expect(estimate.maximumSeconds, 600);
      expect(estimate.isComplete, isFalse);
    },
  );
}
