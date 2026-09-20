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
  Future<void> completeSet(WorkoutSetResultInput result) {
    return remoteDataSource.completeSet({
      'p_result_id': result.resultId,
      'p_actual_reps': result.actualReps,
      'p_actual_duration_seconds': result.actualDurationSeconds,
      'p_actual_distance_meters': result.actualDistanceMeters,
      'p_actual_load_kg': result.actualLoadKg,
      'p_actual_rpe': result.actualRpe,
      'p_actual_rir': result.actualRir,
    });
  }

  @override
  Future<void> skipSet(String resultId) => remoteDataSource.skipSet(resultId);

  @override
  Future<void> finishExecution(String executionId, int finalRpe) =>
      remoteDataSource.finishExecution(executionId, finalRpe);

  @override
  Future<void> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) => remoteDataSource.abandonExecution(executionId, _reasonValue(reason));
}

String _reasonValue(WorkoutAbandonmentReason reason) => switch (reason) {
  WorkoutAbandonmentReason.lackOfTime => 'lack_of_time',
  WorkoutAbandonmentReason.tooDifficult => 'too_difficult',
  WorkoutAbandonmentReason.discomfort => 'discomfort',
  WorkoutAbandonmentReason.other => 'other',
};
