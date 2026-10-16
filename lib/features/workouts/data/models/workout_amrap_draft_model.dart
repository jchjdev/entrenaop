import '../../domain/entities/workout_amrap_draft.dart';

class WorkoutAmrapDraftModel {
  const WorkoutAmrapDraftModel._();

  static WorkoutAmrapDraft fromJson(Map<String, dynamic> json) =>
      WorkoutAmrapDraft(
        rounds: json['rounds'] as String,
        hasPartial: json['hasPartial'] as bool,
        partialItemOrder: json['partialItemOrder'] as int?,
        partialReps: json['partialReps'] as String,
      );

  static Map<String, dynamic> toJson(WorkoutAmrapDraft draft) => {
    'rounds': draft.rounds,
    'hasPartial': draft.hasPartial,
    'partialItemOrder': draft.partialItemOrder,
    'partialReps': draft.partialReps,
  };
}
