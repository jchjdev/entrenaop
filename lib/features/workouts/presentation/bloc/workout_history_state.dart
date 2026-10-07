import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:equatable/equatable.dart';

enum WorkoutHistoryStatus { initial, loading, loaded, failure }

class WorkoutHistoryState extends Equatable {
  const WorkoutHistoryState({
    this.status = WorkoutHistoryStatus.initial,
    this.executions = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.query = const WorkoutHistoryQuery(),
    this.hasMore = false,
    this.isLoadingMore = false,
    this.moreError,
  });

  final WorkoutHistoryStatus status;
  final List<WorkoutExecution> executions;
  final String? errorMessage;
  final bool isRefreshing;
  final WorkoutHistoryQuery query;
  final bool hasMore;
  final bool isLoadingMore;
  final String? moreError;

  WorkoutHistoryState copyWith({
    WorkoutHistoryStatus? status,
    List<WorkoutExecution>? executions,
    bool? isRefreshing,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    String? moreError,
  }) => WorkoutHistoryState(
    status: status ?? this.status,
    executions: executions ?? this.executions,
    query: query,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: errorMessage ?? this.errorMessage,
    moreError: moreError,
  );

  @override
  List<Object?> get props => [
    status,
    executions,
    errorMessage,
    isRefreshing,
    query,
    hasMore,
    isLoadingMore,
    moreError,
  ];
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
