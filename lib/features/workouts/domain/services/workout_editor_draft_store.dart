import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

class WorkoutEditorDraftSnapshot extends Equatable {
  const WorkoutEditorDraftSnapshot({
    required this.input,
    required this.savedAt,
  });

  final CreatePersonalWorkoutInput input;
  final DateTime savedAt;

  @override
  List<Object?> get props => [input, savedAt];
}

abstract class WorkoutEditorDraftStore {
  Future<WorkoutEditorDraftSnapshot?> read(String draftId);

  Future<void> write(String draftId, WorkoutEditorDraftSnapshot snapshot);

  Future<void> clear(String draftId);
}
