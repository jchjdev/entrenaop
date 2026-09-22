import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:entrenaop/features/workout_schedule/data/models/scheduled_workout_model.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';

class WorkoutScheduleRepositoryImpl implements WorkoutScheduleRepository {
  const WorkoutScheduleRepositoryImpl({required this.remoteDataSource});

  final WorkoutScheduleRemoteDataSource remoteDataSource;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async {
    final rows = await remoteDataSource.getRange(_date(start), _date(end));
    return rows.map(ScheduledWorkoutModel.fromJson).toList(growable: false);
  }

  @override
  Future<String> schedule(String templateId, DateTime date, {String? time}) =>
      remoteDataSource.schedule(templateId, _date(date), time: time);

  @override
  Future<void> reschedule(String scheduledId, DateTime date, {String? time}) =>
      remoteDataSource.reschedule(scheduledId, _date(date), time: time);

  @override
  Future<void> cancel(String scheduledId) =>
      remoteDataSource.cancel(scheduledId);

  @override
  Future<String> start(String scheduledId) =>
      remoteDataSource.start(scheduledId);
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
