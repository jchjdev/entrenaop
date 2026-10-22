import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

class WorkoutEditorDraftSnapshot extends Equatable {
  const WorkoutEditorDraftSnapshot({
    required this.input,
    required this.savedAt,
    this.editorState,
  });

  final CreatePersonalWorkoutInput input;
  final DateTime savedAt;

  /// Formulario incompleto del editor común; input conserva compatibilidad
  /// con los borradores anteriores y la última proyección recuperable.
  final Map<String, dynamic>? editorState;

  @override
  List<Object?> get props => [input, savedAt, editorState];
}

abstract class WorkoutEditorDraftStore {
  Future<WorkoutEditorDraftSnapshot?> read(String draftId);

  Future<void> write(String draftId, WorkoutEditorDraftSnapshot snapshot);

  Future<void> clear(String draftId);
}
