enum ActivityProblem {
  wrongOwner,
  wrongScope,
  authorizationRequired,
  staleGeneration,
  staleCursor,
  reusedOperation,
  invalidActivity,
  staleReview,
  unavailableSession,
  activityAlreadyAssociated,
  sessionAlreadyAssociated,
}

/// Expone un código de dominio, nunca el payload o un secreto del proveedor.
final class ActivityException implements Exception {
  const ActivityException(this.problem);

  final ActivityProblem problem;

  @override
  String toString() => 'ActivityException(${problem.name})';
}

void requireIdentifier(String value, String name) {
  if (value.trim().isEmpty) throw ArgumentError('Identificador vacío: $name');
}

void requireUtc(DateTime value) {
  if (!value.isUtc) throw ArgumentError('El instante debe ser UTC');
}
