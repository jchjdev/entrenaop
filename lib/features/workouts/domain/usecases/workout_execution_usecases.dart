import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';

class StartWorkoutExecutionUseCase {
  const StartWorkoutExecutionUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<String> call(String templateId) =>
      _repository.startExecution(templateId);
}

class GetWorkoutExecutionUseCase {
  const GetWorkoutExecutionUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<WorkoutExecution?> call(String executionId) =>
      _repository.getExecution(executionId);
}

class GetWorkoutHistoryUseCase {
  const GetWorkoutHistoryUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<List<WorkoutExecution>> call() => _repository.getExecutionHistory();
}

class CompleteWorkoutSetUseCase {
  const CompleteWorkoutSetUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(WorkoutSetResultInput result) =>
      _repository.completeSet(result);
}

class SkipWorkoutSetUseCase {
  const SkipWorkoutSetUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(String resultId) => _repository.skipSet(resultId);
}

class FinishWorkoutExecutionUseCase {
  const FinishWorkoutExecutionUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(
    String executionId, {
    required int finalRpe,
    String? notes,
  }) => _repository.finishExecution(
    executionId,
    finalRpe: finalRpe,
    notes: notes,
  );
}

class AbandonWorkoutExecutionUseCase {
  const AbandonWorkoutExecutionUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(String executionId, WorkoutAbandonmentReason reason) =>
      _repository.abandonExecution(executionId, reason);
}
