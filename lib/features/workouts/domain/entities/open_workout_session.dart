import 'package:equatable/equatable.dart';

class OpenWorkoutSession extends Equatable {
  const OpenWorkoutSession({
    required this.id,
    required this.name,
    required this.startedAt,
  });

  final String id;
  final String name;
  final DateTime startedAt;

  @override
  List<Object?> get props => [id, name, startedAt];
}

class OpenWorkoutConflict implements Exception {
  const OpenWorkoutConflict(this.executionId, this.name);

  final String executionId;
  final String name;
}
