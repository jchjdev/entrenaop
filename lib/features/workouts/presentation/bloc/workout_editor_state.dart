import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:equatable/equatable.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';

enum WorkoutEditorStatus { initial, loading, ready, saving, saved, failure }

class WorkoutEditorState extends Equatable {
  const WorkoutEditorState({
    this.status = WorkoutEditorStatus.initial,
    this.exercises = const [],
    this.originalTemplate,
    this.draft,
    this.createdTemplateId,
    this.errorMessage,
    this.accessDenied,
  });

  final WorkoutEditorStatus status;
  final List<ExerciseEntity> exercises;
  final WorkoutTemplate? originalTemplate;
  final WorkoutEditorDraftSnapshot? draft;
  final String? createdTemplateId;
  final String? errorMessage;
  final ProAccessDenied? accessDenied;

  @override
  List<Object?> get props => [
    status,
    exercises,
    originalTemplate,
    draft,
    createdTemplateId,
    errorMessage,
    accessDenied,
  ];
}
