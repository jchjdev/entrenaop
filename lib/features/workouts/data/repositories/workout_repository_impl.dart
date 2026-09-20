import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/models/workout_template_model.dart';
import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl({required this.remoteDataSource});

  final WorkoutRemoteDataSource remoteDataSource;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async {
    final json = await remoteDataSource.getTemplateById(id);
    return json == null ? null : WorkoutTemplateModel.fromJson(json);
  }

  @override
  Future<String> startExecution(String templateId) =>
      remoteDataSource.startExecution(templateId);

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async {
    final json = await remoteDataSource.getExecution(executionId);
    return json == null ? null : WorkoutExecutionModel.fromJson(json);
  }

  @override
  Future<void> completeSet(WorkoutExecutionSet set) {
    return remoteDataSource.completeSet({
      'p_result_id': set.id,
      'p_actual_reps': set.targetReps,
      'p_actual_duration_seconds': set.targetDurationSeconds,
      'p_actual_distance_meters': set.targetDistanceMeters,
      'p_actual_load_kg': set.targetLoadKg,
      'p_actual_rpe': set.targetRpe,
      'p_actual_rir': set.targetRir,
    });
  }

  @override
  Future<void> finishExecution(String executionId, int finalRpe) =>
      remoteDataSource.finishExecution(executionId, finalRpe);
}
