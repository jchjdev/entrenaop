enum GarminConnectionStatus {
  disconnected,
  authorizing,
  connected,
  authorizationFailed,
  disconnecting,
  revocationPending,
}

enum GarminConnectionProblem {
  accountChanged,
  accessRequired,
  unavailable,
  conflict,
  rateLimited,
  invalidResponse,
}

class GarminConnectionException implements Exception {
  const GarminConnectionException(this.problem);
  final GarminConnectionProblem problem;
}

class GarminConnectionSnapshot {
  const GarminConnectionSnapshot({
    required this.status,
    required this.allowed,
    required this.generation,
    required this.canRead,
    required this.canSend,
    this.authorizationExpiresAt,
  });
  final GarminConnectionStatus status;
  final bool allowed, canRead, canSend;
  final int generation;
  final DateTime? authorizationExpiresAt;
}

class GarminAuthorization {
  const GarminAuthorization(this.snapshot, this.url);
  final GarminConnectionSnapshot snapshot;
  final Uri url;
}

abstract interface class GarminConnectionRepository {
  Future<GarminConnectionSnapshot> load();
  Future<GarminAuthorization> begin();
  Future<GarminConnectionSnapshot> disconnect(int generation);
}
