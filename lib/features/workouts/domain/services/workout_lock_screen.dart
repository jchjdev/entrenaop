import 'package:equatable/equatable.dart';

/// Información de consulta. El ejecutor es el único que cambia la serie.
class WorkoutLockScreenSnapshot extends Equatable {
  const WorkoutLockScreenSnapshot({
    required this.executionId,
    required this.exercise,
    required this.prescription,
    this.restEndsAt,
  });

  final String executionId;
  final String exercise;
  final String prescription;
  final DateTime? restEndsAt;

  @override
  List<Object?> get props => [executionId, exercise, prescription, restEndsAt];
}

abstract interface class WorkoutLockScreen {
  /// Android devuelve false si la app no puede publicar la notificación.
  Future<bool> show(WorkoutLockScreenSnapshot snapshot);

  Future<void> clear(String executionId);
}
