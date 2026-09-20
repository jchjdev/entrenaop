import 'package:equatable/equatable.dart';

enum WorkoutTimerPhase { preparing, running, paused }

/// Estado local mínimo necesario para reconstruir un temporizador interrumpido.
class WorkoutTimerSnapshot extends Equatable {
  const WorkoutTimerSnapshot({
    required this.phase,
    required this.targetSeconds,
    required this.preparationSeconds,
    required this.phaseStartedAt,
    required this.elapsedBeforeRun,
  });

  final WorkoutTimerPhase phase;
  final int targetSeconds;
  final int preparationSeconds;
  final DateTime phaseStartedAt;
  final Duration elapsedBeforeRun;

  @override
  List<Object?> get props => [
    phase,
    targetSeconds,
    preparationSeconds,
    phaseStartedAt,
    elapsedBeforeRun,
  ];
}

abstract class WorkoutTimerStore {
  Future<WorkoutTimerSnapshot?> read(String timerId);

  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot);

  Future<void> clear(String timerId);
}
