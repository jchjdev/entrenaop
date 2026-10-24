import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_result_review_usecase.dart';

WorkoutExecution entry(String id, DateTime date, {int version = 1}) =>
    WorkoutExecution(
      id: id,
      templateId: 'template',
      templateName: 'Fuerza',
      templateVersion: version,
      status: WorkoutExecutionStatus.completed,
      startedAt: date,
      sets: const [],
    );
void main() {
  test('página con versiones ajenas conserva cursor y permite encontrar anteriores', () async {
    final repository = _Repo();
    final usecase = GetWorkoutComparisonPage(repository);
    final current = entry('current', DateTime.utc(2026, 10, 24));
    final first = await usecase(current, null);
    expect(first.sessions, isEmpty);
    expect(first.nextCursor, isA<WorkoutHistoryCursor>());
    final next = await usecase(current, first.nextCursor);
    expect(next.sessions.single.id, 'older');
    expect(next.nextCursor, isNull);
    expect(repository.queries.first.limit, 31);
    expect(repository.queries.last.before, first.nextCursor);
  });
}

class _Repo implements WorkoutRepository {
  final queries = <WorkoutHistoryQuery>[];
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async {
    queries.add(query);
    if (query.before == null) {
      return List.generate(
        31,
        (i) => entry(
          'unrelated-$i',
          DateTime.utc(2026, 10, 23).subtract(Duration(minutes: i)),
          version: 2,
        ),
      );
    }
    return [entry('older', DateTime.utc(2026, 10, 20))];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
