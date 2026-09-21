import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:equatable/equatable.dart';

enum ActiveWorkoutStatus {
  initial,
  loading,
  ready,
  saving,
  resting,
  completed,
  abandoned,
  failure,
}

class ActiveWorkoutState extends Equatable {
  const ActiveWorkoutState({
    this.status = ActiveWorkoutStatus.initial,
    this.execution,
    this.restSecondsRemaining = 0,
    this.pendingSyncCount = 0,
    this.errorMessage,
  });

  final ActiveWorkoutStatus status;
  final WorkoutExecution? execution;
  final int restSecondsRemaining;
  final int pendingSyncCount;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    execution,
    restSecondsRemaining,
    pendingSyncCount,
    errorMessage,
  ];
}
