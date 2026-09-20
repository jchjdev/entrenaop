import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/repositories/workout_repository_impl.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingWorkoutRemoteDataSource dataSource;
  late WorkoutRepositoryImpl repository;

  setUp(() {
    dataSource = _RecordingWorkoutRemoteDataSource();
    repository = WorkoutRepositoryImpl(remoteDataSource: dataSource);
  });

  test('envía el resultado real sin sustituirlo por la prescripción', () async {
    const result = WorkoutSetResultInput(
      resultId: 'result-1',
      actualReps: 7,
      actualLoadKg: 12.5,
      actualRir: 2,
    );

    await repository.completeSet(result);

    expect(dataSource.completedValues, {
      'p_result_id': 'result-1',
      'p_actual_reps': 7,
      'p_actual_duration_seconds': null,
      'p_actual_distance_meters': null,
      'p_actual_load_kg': 12.5,
      'p_actual_rpe': null,
      'p_actual_rir': 2,
    });
  });

  test('envía el identificador de la serie omitida', () async {
    await repository.skipSet('result-2');

    expect(dataSource.skippedResultId, 'result-2');
  });

  test(
    'traduce el motivo de abandono al valor estable de base de datos',
    () async {
      await repository.abandonExecution(
        'execution-2',
        WorkoutAbandonmentReason.discomfort,
      );

      expect(dataSource.abandonedExecutionId, 'execution-2');
      expect(dataSource.abandonmentReason, 'discomfort');
    },
  );
}

class _RecordingWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  Map<String, dynamic>? completedValues;
  String? skippedResultId;
  String? abandonedExecutionId;
  String? abandonmentReason;

  @override
  Future<void> abandonExecution(String executionId, String reason) async {
    abandonedExecutionId = executionId;
    abandonmentReason = reason;
  }

  @override
  Future<void> completeSet(Map<String, dynamic> values) async {
    completedValues = values;
  }

  @override
  Future<void> skipSet(String resultId) async {
    skippedResultId = resultId;
  }

  @override
  Future<void> finishExecution(String executionId, int finalRpe) async {}

  @override
  Future<Map<String, dynamic>?> getExecution(String executionId) async => null;

  @override
  Future<Map<String, dynamic>?> getTemplateById(String id) async => null;

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
}
