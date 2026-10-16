import 'package:workout_core/performance_set_codec.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_session_set_draft.dart';

class WorkoutSessionSetDraftModel {
  static Map<String, dynamic> toJson(WorkoutSessionSetDraft draft) => {
    'id': draft.result.resultId,
    'fields': draft.fields,
    if (draft.result.performanceResult != null)
      'performance': PerformanceSetCodec.encodeResult(
        draft.result.performanceResult!,
      ),
    'ended': draft.endedAt?.toUtc().toIso8601String(),
    'confirmed': draft.confirmed,
    'saved': draft.saved,
    'correction': draft.needsCorrection,
    'reps': draft.result.actualReps,
    'duration': draft.result.actualDurationSeconds,
    'distance': draft.result.actualDistanceMeters,
    'load': draft.result.actualLoadKg,
    'rpe': draft.result.actualRpe,
    'rir': draft.result.actualRir,
    'recovery_duration': draft.result.actualRecoveryDurationSeconds,
    'recovery_distance': draft.result.actualRecoveryDistanceMeters,
  };

  static WorkoutSessionSetDraft fromJson(Map<String, dynamic> json) =>
      WorkoutSessionSetDraft(
        result: WorkoutSetResultInput(
          resultId: json['id'] as String,
          performanceResult: json['performance'] == null
              ? null
              : PerformanceSetCodec.result(
                  Map<String, dynamic>.from(json['performance'] as Map),
                ),
          actualReps: json['reps'] as int?,
          actualDurationSeconds: json['duration'] as int?,
          actualDistanceMeters: (json['distance'] as num?)?.toDouble(),
          actualLoadKg: (json['load'] as num?)?.toDouble(),
          actualRpe: (json['rpe'] as num?)?.toDouble(),
          actualRir: (json['rir'] as num?)?.toDouble(),
          actualRecoveryDurationSeconds: json['recovery_duration'] as int?,
          actualRecoveryDistanceMeters: (json['recovery_distance'] as num?)
              ?.toDouble(),
        ),
        fields: Map<String, String>.from(json['fields'] as Map),
        endedAt: json['ended'] == null
            ? null
            : DateTime.parse(json['ended'] as String),
        confirmed: json['confirmed'] as bool,
        saved: json['saved'] as bool,
        needsCorrection: json['correction'] as bool,
      );
}
