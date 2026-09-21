import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum WorkoutEditorStatus { initial, loading, ready, saving, saved, failure }

class WorkoutEditorState extends Equatable {
  const WorkoutEditorState({
    this.status = WorkoutEditorStatus.initial,
    this.exercises = const [],
    this.originalTemplate,
    this.createdTemplateId,
    this.errorMessage,
  });

  final WorkoutEditorStatus status;
  final List<ExerciseEntity> exercises;
  final WorkoutTemplate? originalTemplate;
  final String? createdTemplateId;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    exercises,
    originalTemplate,
    createdTemplateId,
    errorMessage,
  ];
}
