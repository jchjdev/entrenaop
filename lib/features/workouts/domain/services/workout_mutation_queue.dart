import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';

abstract class WorkoutMutationQueue {
  Future<List<PendingWorkoutMutation>> readAll();

  Future<void> enqueue(PendingWorkoutMutation mutation);

  Future<void> remove(String operationId);
}
