import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';

abstract class WorkoutRepository {
  Future<WorkoutTemplate?> getTemplateById(String id);

  Future<String> startExecution(String templateId);

  Future<WorkoutExecution?> getExecution(String executionId);

  Future<void> completeSet(WorkoutSetResultInput result);

  Future<void> skipSet(String resultId);

  Future<void> finishExecution(String executionId, int finalRpe);

  Future<void> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  );
}
