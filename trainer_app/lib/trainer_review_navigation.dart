import 'trainer_operations_repository.dart';

class TrainerNextReviewPage {
  const TrainerNextReviewPage({this.next, this.cursor, required this.hasMore});
  final TrainerReviewItem? next, cursor;
  final bool hasMore;
}

/// Conserva el cursor bruto aunque la página no contenga al alumno buscado.
/// Una página sin coincidencias no acredita que se haya terminado la bandeja.
Future<TrainerNextReviewPage> loadTrainerNextReviewPage(
  TrainerOperationsRepository repository, {
  required String currentAssignmentId,
  String? clientId,
  TrainerReviewItem? after,
}) async {
  final rows = await repository.reviews(before: after);
  final next = rows
      .where(
        (item) =>
            item.assignment.id != currentAssignmentId &&
            (clientId == null || item.clientId == clientId) &&
            const ['completed', 'abandoned'].contains(item.assignment.status) &&
            item.assignment.executionId != null,
      )
      .firstOrNull;
  return TrainerNextReviewPage(
    next: next,
    cursor: rows.lastOrNull,
    hasMore: rows.length == 100,
  );
}
