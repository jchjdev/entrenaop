import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:equatable/equatable.dart';

enum WorkoutEditorStatus { initial, loading, ready, saving, saved, failure }

class WorkoutEditorState extends Equatable {
  const WorkoutEditorState({
    this.status = WorkoutEditorStatus.initial,
    this.exercises = const [],
    this.createdTemplateId,
    this.errorMessage,
  });

  final WorkoutEditorStatus status;
  final List<ExerciseEntity> exercises;
  final String? createdTemplateId;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    exercises,
    createdTemplateId,
    errorMessage,
  ];
}
