import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:equatable/equatable.dart';

import '../../domain/services/workout_amrap_draft_store.dart';

enum ActiveWorkoutStatus {
  initial,
  loading,
  ready,
  saving,
  resting,
  completed,
  abandoned,
  discarded,
  failure,
}

class ActiveWorkoutState extends Equatable {
  const ActiveWorkoutState({
    this.status = ActiveWorkoutStatus.initial,
    this.execution,
    this.restSecondsRemaining = 0,
    this.restCanBeSkipped = true,
    this.pendingSyncCount = 0,
    this.errorMessage,
    this.drafts = const {},
    this.exercises = const {},
    this.draftBusy = false,
    this.amrapDrafts = const {},
  });

  final ActiveWorkoutStatus status;
  final WorkoutExecution? execution;
  final int restSecondsRemaining;
  final bool restCanBeSkipped;
  final int pendingSyncCount;
  final String? errorMessage;
  final Map<String, WorkoutSessionSetDraft> drafts;
  final Map<String, ExerciseEntity> exercises;
  final bool draftBusy;
  final Map<int, WorkoutAmrapDraft> amrapDrafts;
  int get unconfirmedDraftCount =>
      drafts.values.where((d) => d.endedAt != null && !d.confirmed).length;

  WorkoutExecutionSet? get latestUnconfirmedSet {
    WorkoutExecutionSet? latest;
    DateTime? endedAt;
    for (final set in execution?.sets ?? <WorkoutExecutionSet>[]) {
      final draft = drafts[set.id];
      if (set.status != WorkoutSetStatus.completed ||
          draft == null ||
          draft.confirmed ||
          draft.endedAt == null) {
        continue;
      }
      if (endedAt == null || !draft.endedAt!.isBefore(endedAt)) {
        latest = set;
        endedAt = draft.endedAt;
      }
    }
    return latest;
  }

  @override
  List<Object?> get props => [
    status,
    execution,
    restSecondsRemaining,
    restCanBeSkipped,
    pendingSyncCount,
    errorMessage,
    drafts,
    exercises,
    draftBusy,
    amrapDrafts,
  ];
}
