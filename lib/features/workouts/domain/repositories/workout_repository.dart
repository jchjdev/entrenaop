import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';

abstract class WorkoutRepository {
  Future<WorkoutTemplate?> getTemplateById(String id);

  Future<String> startExecution(String templateId);

  Future<WorkoutExecution?> getExecution(String executionId);

  Future<List<WorkoutExecution>> getExecutionHistory();

  Future<WorkoutMutationDisposition> completeSet(WorkoutSetResultInput result);

  Future<void> correctSet(WorkoutSetCorrectionInput correction);

  Future<WorkoutMutationDisposition> skipSet(String resultId);

  Future<WorkoutMutationDisposition> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
  });

  Future<WorkoutMutationDisposition> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  );

  Future<int> getPendingMutationCount();

  Future<void> syncPendingMutations();
}
