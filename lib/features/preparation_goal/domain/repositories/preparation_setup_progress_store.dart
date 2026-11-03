/// Posición de la interfaz; no acredita datos válidos ni activa un plan.
enum PreparationSetupStep {
  program,
  availability,
  running,
  movements,
  proposal,
}

abstract class PreparationSetupProgressStore {
  Future<PreparationSetupStep?> read(String goalId);
  Future<void> write(String goalId, PreparationSetupStep step);
  Future<void> clear(String goalId);
}
