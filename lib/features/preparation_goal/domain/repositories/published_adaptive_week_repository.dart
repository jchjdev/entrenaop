/// Instantáneas vigentes publicadas por el servidor, sin recalcular progresiones.
class PublishedAdaptiveWeek {
  const PublishedAdaptiveWeek({this.preparationDecision, this.runningDecision});

  final Map<String, dynamic>? preparationDecision;
  final Map<String, dynamic>? runningDecision;
}

abstract interface class PublishedAdaptiveWeekRepository {
  Future<PublishedAdaptiveWeek> read(String goalId, DateTime week);
}

class PublishedAdaptiveWeekException implements Exception {
  const PublishedAdaptiveWeekException(this.message);

  final String message;

  @override
  String toString() => message;
}
