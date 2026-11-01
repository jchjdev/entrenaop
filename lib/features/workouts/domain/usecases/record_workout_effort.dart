abstract interface class WorkoutEffortRepository {
  Future<void> record(String executionId, int rpe);
}

/// Completa un dato subjetivo pendiente; nunca lo deduce del ritmo o del pulso.
class RecordWorkoutEffort {
  const RecordWorkoutEffort(this.repository);
  final WorkoutEffortRepository repository;

  Future<void> call(String executionId, int rpe) {
    if (executionId.isEmpty || rpe < 1 || rpe > 10) {
      throw ArgumentError('El esfuerzo debe estar entre 1 y 10.');
    }
    return repository.record(executionId, rpe);
  }
}
