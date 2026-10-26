/// Preferencia de presentación; no interviene en permisos ni suscripciones.
abstract interface class WelcomeRepository {
  Future<bool> isCompleted(String userId);
  Future<void> complete(String userId);
  void skipForSession(String userId);
}
