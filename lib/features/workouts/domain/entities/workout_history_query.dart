import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:equatable/equatable.dart';

class WorkoutHistoryCursor extends Equatable {
  const WorkoutHistoryCursor({required this.startedAt, required this.id});
  final DateTime startedAt;
  final String id;
  @override
  List<Object?> get props => [startedAt, id];
}

/// Criterios de lectura; no cambian sesiones ni reglas de entrenamiento.
class WorkoutHistoryQuery extends Equatable {
  const WorkoutHistoryQuery({
    this.limit = 30,
    this.before,
    this.preparationGoalId,
    this.from,
    this.through,
    this.status,
  }) : assert(limit > 0),
       assert(status != WorkoutExecutionStatus.inProgress);

  final int limit;
  final WorkoutHistoryCursor? before;
  final String? preparationGoalId;
  final DateTime? from;
  final DateTime? through;
  final WorkoutExecutionStatus? status;

  WorkoutHistoryQuery page({
    required int limit,
    WorkoutHistoryCursor? before,
  }) => WorkoutHistoryQuery(
    limit: limit,
    before: before,
    preparationGoalId: preparationGoalId,
    from: from,
    through: through,
    status: status,
  );

  bool get hasFilters =>
      preparationGoalId != null ||
      from != null ||
      through != null ||
      status != null;

  @override
  List<Object?> get props => [
    limit,
    before,
    preparationGoalId,
    from,
    through,
    status,
  ];
}
