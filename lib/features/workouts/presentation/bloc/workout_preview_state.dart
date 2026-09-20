import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum WorkoutPreviewStatus { initial, loading, ready, starting, empty, failure }

class WorkoutPreviewState extends Equatable {
  const WorkoutPreviewState({
    this.status = WorkoutPreviewStatus.initial,
    this.workout,
    this.executionId,
    this.errorMessage,
  });

  final WorkoutPreviewStatus status;
  final WorkoutTemplate? workout;
  final String? executionId;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, workout, executionId, errorMessage];
}
