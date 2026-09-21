import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:entrenaop/features/workout_schedule/data/repositories/workout_schedule_repository_impl.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'convierte la instantánea programada sin depender de la plantilla',
    () async {
      final remote = _FakeRemoteDataSource(
        rows: [
          {
            'id': 'scheduled-1',
            'template_id': 'template-1',
            'template_name': 'Dominadas base',
            'template_version': 3,
            'estimated_duration_minutes': 35,
            'execution_id': null,
            'scheduled_date': '2026-09-21',
            'scheduled_time': '18:30:00',
            'source': 'user',
            'status': 'planned',
          },
        ],
      );
      final repository = WorkoutScheduleRepositoryImpl(
        remoteDataSource: remote,
      );

      final result = await repository.getRange(
        DateTime(2026, 9, 21, 10),
        DateTime(2026, 9, 27, 23),
      );

      expect(remote.lastStart, '2026-09-21');
      expect(remote.lastEnd, '2026-09-27');
      expect(result.single.templateName, 'Dominadas base');
      expect(result.single.templateVersion, 3);
      expect(result.single.source, ScheduledWorkoutSource.user);
      expect(result.single.status, ScheduledWorkoutStatus.planned);
    },
  );

  test('serializa solo la fecha al programar y reprogramar', () async {
    final remote = _FakeRemoteDataSource();
    final repository = WorkoutScheduleRepositoryImpl(remoteDataSource: remote);

    await repository.schedule('template-1', DateTime(2026, 9, 22, 19));
    await repository.reschedule('scheduled-1', DateTime(2026, 10, 3, 8));

    expect(remote.scheduledDate, '2026-09-22');
    expect(remote.rescheduledDate, '2026-10-03');
  });
}

class _FakeRemoteDataSource implements WorkoutScheduleRemoteDataSource {
  _FakeRemoteDataSource({this.rows = const []});

  final List<Map<String, dynamic>> rows;
  String? lastStart;
  String? lastEnd;
  String? scheduledDate;
  String? rescheduledDate;

  @override
  Future<List<Map<String, dynamic>>> getRange(String start, String end) async {
    lastStart = start;
    lastEnd = end;
    return rows;
  }

  @override
  Future<String> schedule(
    String templateId,
    String date, {
    String? time,
  }) async {
    scheduledDate = date;
    return 'scheduled-1';
  }

  @override
  Future<void> reschedule(
    String scheduledId,
    String date, {
    String? time,
  }) async {
    rescheduledDate = date;
  }

  @override
  Future<void> cancel(String scheduledId) async {}

  @override
  Future<String> start(String scheduledId) async => 'execution-1';
}
