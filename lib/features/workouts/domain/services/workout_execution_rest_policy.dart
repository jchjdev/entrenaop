import '../entities/workout_execution.dart';
import '../entities/workout_template.dart';

/// La vista proporciona el tiempo medido; dominio decide la recuperación.
int workoutRestAfterSet(WorkoutExecutionSet set, {int? elapsedSeconds}) =>
    switch (set.blockFormat) {
      WorkoutBlockFormat.running => 0,
      WorkoutBlockFormat.emom =>
        (60 - (elapsedSeconds ?? 0)).clamp(0, 60).toInt(),
      _ => set.restAfterSeconds.clamp(0, 3600).toInt(),
    };

int? workoutRestAfterSkipping(WorkoutExecutionSet set, {int? elapsedSeconds}) =>
    set.blockFormat == WorkoutBlockFormat.emom
    ? workoutRestAfterSet(set, elapsedSeconds: elapsedSeconds)
    : null;
