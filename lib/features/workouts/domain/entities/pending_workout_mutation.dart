import 'package:equatable/equatable.dart';

enum WorkoutMutationType { completeSet, skipSet, finish, abandon }

enum WorkoutMutationDisposition { synced, queued }

class PendingWorkoutMutation extends Equatable {
  const PendingWorkoutMutation({
    required this.operationId,
    required this.type,
    required this.resourceId,
    required this.values,
    required this.createdAt,
  });

  final String operationId;
  final WorkoutMutationType type;
  final String resourceId;
  final Map<String, dynamic> values;
  final DateTime createdAt;

  @override
  List<Object?> get props => [operationId, type, resourceId, values, createdAt];
}
