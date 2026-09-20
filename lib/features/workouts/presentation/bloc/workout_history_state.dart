import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:equatable/equatable.dart';

enum WorkoutHistoryStatus { initial, loading, loaded, failure }

class WorkoutHistoryState extends Equatable {
  const WorkoutHistoryState({
    this.status = WorkoutHistoryStatus.initial,
    this.executions = const [],
    this.errorMessage,
  });

  final WorkoutHistoryStatus status;
  final List<WorkoutExecution> executions;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, executions, errorMessage];
}

enum WorkoutHistoryDetailStatus { initial, loading, loaded, failure }

class WorkoutHistoryDetailState extends Equatable {
  const WorkoutHistoryDetailState({
    this.status = WorkoutHistoryDetailStatus.initial,
    this.execution,
    this.errorMessage,
    this.isCorrecting = false,
    this.correctionMessage,
  });

  final WorkoutHistoryDetailStatus status;
  final WorkoutExecution? execution;
  final String? errorMessage;
  final bool isCorrecting;
  final String? correctionMessage;

  @override
  List<Object?> get props => [
    status,
    execution,
    errorMessage,
    isCorrecting,
    correctionMessage,
  ];
}
