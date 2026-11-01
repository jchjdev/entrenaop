/// Un aviso del sistema despierta el mismo caso de uso autenticado que la UI.
/// El adaptador no recibe tokens, recetas ni mediciones de Salud.
abstract interface class AppleResultsWakeup {
  Future<bool> configure(String? owner, Future<bool> Function() synchronize);
  Future<void> dispose();
}
