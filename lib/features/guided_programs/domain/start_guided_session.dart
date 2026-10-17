import '../../workouts/domain/repositories/workout_repository.dart';
import 'guided_program_repository.dart';

/// Tras una respuesta incierta se reenvía la misma operación y sus ajustes.
class StartGuidedSession {
  StartGuidedSession({
    required this.repository,
    required this.workouts,
    required this.programId,
    required this.phaseIndex,
    required this.sessionIndex,
    required this.operationId,
  });
  final GuidedProgramRepository repository;
  final WorkoutRepository workouts;
  final String programId, operationId;
  final int phaseIndex, sessionIndex;
  bool? _omit;
  int? _rest;
  Future<String> call({required bool omitWarmup, int? restSeconds}) async {
    final owner = repository.currentUserId;
    if (owner == null) {
      throw StateError('Debes iniciar sesión.');
    }
    if (_omit == null) {
      _omit = omitWarmup;
      _rest = restSeconds;
    }
    // Un cierre pendiente debe sincronizarse antes de decidir si hay sesión activa.
    await workouts.syncPendingMutations();
    if (repository.currentUserId != owner) {
      throw StateError('La cuenta cambió mientras se preparaba la sesión.');
    }
    return repository.start(
      programId: programId,
      phaseIndex: phaseIndex,
      sessionIndex: sessionIndex,
      operationId: operationId,
      omitWarmup: _omit!,
      restSeconds: _rest,
    );
  }
}
