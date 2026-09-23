import 'package:workout_core/workout_template.dart';

Map<String, dynamic> workoutDraftToJson(CreatePersonalWorkoutInput input) => {
  'name': input.name.trim(),
  'description': input.description?.trim(),
  'estimated_duration_minutes': input.estimatedDurationMinutes,
  'blocks': input.blocks
      .map(
        (block) => {
          'name': block.name.trim(),
          'format': _blockFormatValue(block.format),
          'rounds': block.rounds,
          if (block.timeCapSeconds != null)
            'time_cap_seconds': block.timeCapSeconds,
          'rest_after_seconds': block.restAfterSeconds,
          'exercises': block.exercises
              .map(
                (exercise) => {
                  'exercise_id': exercise.exerciseId,
                  'sets': exercise.sets.map(_setDraftToJson).toList(),
                },
              )
              .toList(),
        },
      )
      .toList(),
};

String _blockFormatValue(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.straightSets => 'straight_sets',
  WorkoutBlockFormat.circuit => 'circuit',
  WorkoutBlockFormat.superset => 'superset',
  WorkoutBlockFormat.intervals => 'intervals',
  WorkoutBlockFormat.emom => 'emom',
  WorkoutBlockFormat.amrap => 'amrap',
  WorkoutBlockFormat.tabata => 'tabata',
  WorkoutBlockFormat.running => 'running',
  WorkoutBlockFormat.warmUp => 'warm_up',
  WorkoutBlockFormat.coolDown => 'cool_down',
};

Map<String, dynamic> _setDraftToJson(WorkoutSetDraft set) => {
  'target_reps': set.targetType == WorkoutTargetType.repetitions
      ? set.targetValue.round()
      : null,
  'target_duration_seconds': set.targetType == WorkoutTargetType.duration
      ? set.targetValue.round()
      : null,
  'target_distance_meters': set.targetType == WorkoutTargetType.distance
      ? set.targetValue
      : null,
  'target_load_kg': set.targetLoadKg,
  'target_rir': set.targetRir,
  'target_pace_min_seconds_per_km': set.targetPaceMinSecondsPerKm,
  'target_pace_max_seconds_per_km': set.targetPaceMaxSecondsPerKm,
  'recovery_type': switch (set.recoveryType) {
    RunningRecoveryType.passive => 'passive',
    RunningRecoveryType.walking => 'walking',
    RunningRecoveryType.jogging => 'jogging',
    null => null,
  },
  'recovery_duration_seconds': set.recoveryDurationSeconds,
  'recovery_distance_meters': set.recoveryDistanceMeters,
  'rest_after_seconds': set.restAfterSeconds,
};
