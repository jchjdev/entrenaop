import 'dart:convert';

import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutEditorDraftStore
    implements WorkoutEditorDraftStore {
  const SharedPreferencesWorkoutEditorDraftStore(this._preferences);

  static const _prefix = 'workout_editor_draft_v1:';
  final SharedPreferences _preferences;

  @override
  Future<WorkoutEditorDraftSnapshot?> read(String draftId) async {
    final encoded = _preferences.getString('$_prefix$draftId');
    if (encoded == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      return WorkoutEditorDraftSnapshot(
        input: _inputFromJson(Map<String, dynamic>.from(json['input'] as Map)),
        savedAt: DateTime.parse(json['saved_at'] as String),
      );
    } on Object {
      await clear(draftId);
      return null;
    }
  }

  @override
  Future<void> write(String draftId, WorkoutEditorDraftSnapshot snapshot) =>
      _preferences.setString(
        '$_prefix$draftId',
        jsonEncode({
          'saved_at': snapshot.savedAt.toUtc().toIso8601String(),
          'input': _inputToJson(snapshot.input),
        }),
      );

  @override
  Future<void> clear(String draftId) => _preferences.remove('$_prefix$draftId');
}

Map<String, dynamic> _inputToJson(CreatePersonalWorkoutInput input) => {
  'name': input.name,
  'description': input.description,
  'estimated_duration_minutes': input.estimatedDurationMinutes,
  'blocks': input.blocks
      .map(
        (block) => {
          'name': block.name,
          'format': block.format.name,
          'rounds': block.rounds,
          'rest_after_seconds': block.restAfterSeconds,
          'time_cap_seconds': block.timeCapSeconds,
          'exercises': block.exercises
              .map(
                (exercise) => {
                  'exercise_id': exercise.exerciseId,
                  'sets': exercise.sets
                      .map(
                        (set) => {
                          'target_type': set.targetType.name,
                          'target_value': set.targetValue,
                          'rest_after_seconds': set.restAfterSeconds,
                          'target_load_kg': set.targetLoadKg,
                          'target_rir': set.targetRir,
                          'target_pace_min_seconds_per_km':
                              set.targetPaceMinSecondsPerKm,
                          'target_pace_max_seconds_per_km':
                              set.targetPaceMaxSecondsPerKm,
                          'recovery_type': set.recoveryType?.name,
                          'recovery_duration_seconds':
                              set.recoveryDurationSeconds,
                          'recovery_distance_meters':
                              set.recoveryDistanceMeters,
                        },
                      )
                      .toList(growable: false),
                },
              )
              .toList(growable: false),
        },
      )
      .toList(growable: false),
};

CreatePersonalWorkoutInput _inputFromJson(
  Map<String, dynamic> json,
) => CreatePersonalWorkoutInput(
  name: json['name'] as String,
  description: json['description'] as String?,
  estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
  blocks: (json['blocks'] as List)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .map(
        (block) => WorkoutBlockDraft(
          name: block['name'] as String,
          format: WorkoutBlockFormat.values.byName(block['format'] as String),
          rounds: block['rounds'] as int,
          restAfterSeconds: block['rest_after_seconds'] as int,
          timeCapSeconds: block['time_cap_seconds'] as int?,
          exercises: (block['exercises'] as List)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .map(
                (exercise) => WorkoutExerciseDraft(
                  exerciseId: exercise['exercise_id'] as String,
                  sets: (exercise['sets'] as List)
                      .map((value) => Map<String, dynamic>.from(value as Map))
                      .map(
                        (set) => WorkoutSetDraft(
                          targetType: WorkoutTargetType.values.byName(
                            set['target_type'] as String,
                          ),
                          targetValue: (set['target_value'] as num).toDouble(),
                          restAfterSeconds: set['rest_after_seconds'] as int,
                          targetLoadKg: (set['target_load_kg'] as num?)
                              ?.toDouble(),
                          targetRir: (set['target_rir'] as num?)?.toDouble(),
                          targetPaceMinSecondsPerKm:
                              set['target_pace_min_seconds_per_km'] as int?,
                          targetPaceMaxSecondsPerKm:
                              set['target_pace_max_seconds_per_km'] as int?,
                          recoveryType: set['recovery_type'] == null
                              ? null
                              : RunningRecoveryType.values.byName(
                                  set['recovery_type'] as String,
                                ),
                          recoveryDurationSeconds:
                              set['recovery_duration_seconds'] as int?,
                          recoveryDistanceMeters:
                              (set['recovery_distance_meters'] as num?)
                                  ?.toDouble(),
                        ),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false),
);
