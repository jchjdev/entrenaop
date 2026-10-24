import 'package:workout_core/workout_result_review.dart';

import '../entities/workout_execution.dart';
import '../entities/workout_history_query.dart';
import '../repositories/workout_repository.dart';
import '../services/workout_result_review.dart';

class GetWorkoutComparisonPage {
  const GetWorkoutComparisonPage(this.repository);
  final WorkoutRepository repository;
  Future<ReviewHistoryPage> call(
    WorkoutExecution current,
    Object? cursor,
  ) async {
    const size = 30;
    final rows = await repository.getExecutionHistory(
      query: WorkoutHistoryQuery(
        limit: size + 1,
        before: cursor as WorkoutHistoryCursor?,
      ),
    );
    final page = rows.take(size).toList();
    final snapshot = reviewExecution(current);
    return ReviewHistoryPage(
      page.map(reviewExecution).where(snapshot.canCompare).toList(),
      nextCursor: rows.length > size
          ? WorkoutHistoryCursor(
              startedAt: page.last.startedAt,
              id: page.last.id,
            )
          : null,
    );
  }
}
