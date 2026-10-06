import 'package:equatable/equatable.dart';

enum WorkoutMutationType {
  completeSet,
  completeAmrap,
  skipSet,
  finish,
  abandon,
}

enum WorkoutMutationDisposition { synced, queued }

class PendingWorkoutMutation extends Equatable {
  const PendingWorkoutMutation({
    required this.userId,
    required this.operationId,
    required this.type,
    required this.resourceId,
    required this.values,
    required this.createdAt,
  });

  final String operationId;
  final String userId;
  final WorkoutMutationType type;
  final String resourceId;
  final Map<String, dynamic> values;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    userId,
    operationId,
    type,
    resourceId,
    values,
    createdAt,
  ];
}
