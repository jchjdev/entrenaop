import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:entrenaop/features/workout_schedule/data/repositories/workout_schedule_repository_impl.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un resultado identifica solo la pauta vigente con soporte de repetición', () async {
    final row = <String, dynamic>{
      'id': 'scheduled-1',
      'template_id': 'template-1',
      'template_name': 'Rodaje',
      'template_version': 1,
      'scheduled_date': '2026-11-21',
      'source': 'user',
      'status': 'abandoned',
      'execution_id': 'result-1',
      'repeat_execution_id': 'open-attempt',
    };
    final remote = _FakeRemoteDataSource(rows: [row]);
    final lookup = GetRepeatableScheduledWorkoutUseCase(
      WorkoutScheduleRepositoryImpl(remoteDataSource: remote),
    );

    final item = await lookup('result-1');
    expect(remote.lastResultId, 'result-1');
    expect(item?.id, 'scheduled-1');
    expect(item?.repeatExecutionId, 'open-attempt');
    expect(await lookup('older-attempt'), isNull);

    row.remove('repeat_execution_id');
    expect(await lookup('result-1'), isNull);
  });

  test('una pauta pendiente conserva a la vez resultados Garmin y Apple sin completarse', () async {
    final remote = _FakeRemoteDataSource(
      rows: [
        {
          'id': 's',
          'template_id': 't',
          'template_name': 'Series',
          'template_version': 1,
          'scheduled_date': '2026-11-03',
          'source': 'coach',
          'status': 'planned',
          'device_results': [
            for (final provider in ['apple', 'garmin'])
              {
                'id': provider,
                'scheduled_id': 's',
                'provider': provider,
                'name': 'Series',
                'started_at': '2026-11-03T08:00:00Z',
                'timer_seconds': 1900,
                'distance_meters': 5400,
                'state': 'review',
              },
          ],
        },
      ],
    );
    final rows = await WorkoutScheduleRepositoryImpl(remoteDataSource: remote)
        .getRange(DateTime(2026, 11, 2), DateTime(2026, 11, 8));
    expect(rows.single.deviceResults.map((r) => r.provider), [
      'apple',
      'garmin',
    ]);
    expect(rows.single.status, ScheduledWorkoutStatus.planned);
    expect(rows.single.executionId, isNull);
  });
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
            'preparation_goal_id': 'goal-1',
            'execution_id': null,
            'scheduled_date': '2026-09-21',
            'scheduled_time': '18:30:00',
            'source': 'user',
            'status': 'planned',
            'trainer_assignments': {'note': 'Cuida la técnica'},
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
      expect(result.single.preparationGoalId, 'goal-1');
      expect(result.single.coachNote, 'Cuida la técnica');
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
  String? lastResultId;

  @override
  Future<List<Map<String, dynamic>>> getRange(String start, String end) async {
    lastStart = start;
    lastEnd = end;
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> getByResult(String executionId) async {
    lastResultId = executionId;
    return rows.singleOrNull;
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

  @override
  Future<String> repeat(String scheduledId) async => 'execution-repeat';
}
