import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';

class GetWorkoutScheduleUseCase {
  const GetWorkoutScheduleUseCase(this._repository);
  final WorkoutScheduleRepository _repository;

  Future<List<ScheduledWorkout>> call(DateTime start, DateTime end) =>
      _repository.getRange(start, end);
}

class ScheduleWorkoutUseCase {
  const ScheduleWorkoutUseCase(this._repository);
  final WorkoutScheduleRepository _repository;

  Future<String> call(String templateId, DateTime date, {String? time}) =>
      _repository.schedule(templateId, date, time: time);
}

class RescheduleWorkoutUseCase {
  const RescheduleWorkoutUseCase(this._repository);
  final WorkoutScheduleRepository _repository;

  Future<void> call(String scheduledId, DateTime date, {String? time}) =>
      _repository.reschedule(scheduledId, date, time: time);
}

class CancelScheduledWorkoutUseCase {
  const CancelScheduledWorkoutUseCase(this._repository);
  final WorkoutScheduleRepository _repository;

  Future<void> call(String scheduledId) => _repository.cancel(scheduledId);
}

class StartScheduledWorkoutUseCase {
  const StartScheduledWorkoutUseCase(this._repository);
  final WorkoutScheduleRepository _repository;

  Future<String> call(String scheduledId) => _repository.start(scheduledId);
}
