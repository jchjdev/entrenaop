import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';

abstract class WorkoutRepository {
  Future<WorkoutTemplate?> getTemplateById(String id);

  Future<String> startExecution(String templateId);

  Future<WorkoutExecution?> getExecution(String executionId);

  Future<void> completeSet(WorkoutExecutionSet set);

  Future<void> finishExecution(String executionId, int finalRpe);
}
