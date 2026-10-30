import 'package:workout_core/performance_set_codec.dart';
import 'package:workout_core/running_step_codec.dart';
import 'package:workout_core/workout_result_review.dart';
import 'package:workout_core/running_pace_analysis.dart';

import '../entities/workout_execution.dart';

RunningPaceAnalysis runningPaceExecution(
  WorkoutExecution execution,
  ReviewSession review,
) {
  if (review.id != execution.id ||
      review.sets.length != execution.sets.length) {
    throw ArgumentError('La revisión debe pertenecer a la misma ejecución.');
  }
  return RunningPaceAnalysis([
    for (var i = 0; i < execution.sets.length; i++)
      RunningPaceSample(
        review: review.sets[i],
        kind: execution.sets[i].runningStep?.kind,
        recoveryType: execution.sets[i].recoveryType?.name,
        restAfterSeconds: execution.sets[i].restAfterSeconds,
      ),
  ]);
}

ReviewSession reviewExecution(
  WorkoutExecution execution,
) => reviewSessionFromJson({
  'id': execution.id,
  'template_id': execution.templateId,
  'template_name': execution.templateName,
  'template_version': execution.templateVersion,
  'status': execution.status.name,
  'started_at': execution.startedAt.toIso8601String(),
  'final_rpe': execution.finalRpe,
  'workout_amrap_results': [
    for (final r in execution.amrapResults)
      {
        'block_order': r.blockOrder,
        'completed_rounds': r.completedRounds,
        'partial_item_order': r.partialItemOrder,
        'partial_reps': r.partialReps,
      },
  ],
  'workout_execution_sets': [
    for (final set in execution.sets)
      {
        'id': set.id,
        'block_order': set.blockOrder,
        'item_order': set.itemOrder,
        'set_order': set.setOrder,
        'exercise_id': set.exerciseId,
        'exercise_name': set.exerciseName,
        'block_name': set.blockName,
        'block_format': switch (set.blockFormat.name) {
          'straightSets' => 'straight_sets',
          'warmUp' => 'warm_up',
          'coolDown' => 'cool_down',
          _ => set.blockFormat.name,
        },
        'status': set.status.name,
        'rest_after_seconds': set.restAfterSeconds,
        'block_time_cap_seconds': set.blockTimeCapSeconds,
        'running_step': set.runningStep == null
            ? null
            : RunningStepCodec.encode(set.runningStep!),
        'recovery_type': set.recoveryType?.name,
        'target_reps': set.targetReps,
        'target_duration_seconds': set.targetDurationSeconds,
        'target_distance_meters': set.targetDistanceMeters,
        'target_load_kg': set.targetLoadKg,
        'target_rir': set.targetRir,
        'target_rpe': set.targetRpe,
        'target_pace_min_seconds_per_km': set.targetPaceMinSecondsPerKm,
        'target_pace_max_seconds_per_km': set.targetPaceMaxSecondsPerKm,
        'recovery_duration_seconds': set.recoveryDurationSeconds,
        'recovery_distance_meters': set.recoveryDistanceMeters,
        'actual_reps': set.actualReps,
        'actual_duration_seconds': set.actualDurationSeconds,
        'actual_distance_meters': set.actualDistanceMeters,
        'actual_load_kg': set.actualLoadKg,
        'actual_rir': set.actualRir,
        'actual_rpe': set.actualRpe,
        'actual_recovery_duration_seconds': set.actualRecoveryDurationSeconds,
        'actual_recovery_distance_meters': set.actualRecoveryDistanceMeters,
        'observed_duration_seconds': set.observedDurationSeconds,
        'observed_recovery_duration_seconds':
            set.observedRecoveryDurationSeconds,
        'result_source': set.resultSource?.name,
        'performance_prescription': set.performancePrescription == null
            ? null
            : {
                'exercise_code': set.performancePrescription!.exerciseCode,
                'exercise_version':
                    set.performancePrescription!.exerciseVersion,
                'protocol_key': set.performancePrescription!.protocolKey,
                'protocol_version':
                    set.performancePrescription!.protocolVersion,
                'setup_key': set.performancePrescription!.setupKey,
                'measurement': set.performancePrescription!.measurement,
                'load_mode': set.performancePrescription!.loadMode,
                'intent': set.performancePrescription!.intent,
                'target_value': set.performancePrescription!.targetValue,
                'external_load_kg': set.performancePrescription!.externalLoadKg,
                'target_rir': set.performancePrescription!.targetRir,
                'target_rpe': set.performancePrescription!.targetRpe,
                'fixed_duration_seconds':
                    set.performancePrescription!.fixedDurationSeconds,
                'fixed_distance_meters':
                    set.performancePrescription!.fixedDistanceMeters,
                'effort_mode': set.performancePrescription!.effortMode,
              },
        'performance_result': set.performanceResult == null
            ? null
            : PerformanceSetCodec.encodeResult(set.performanceResult!),
      },
  ],
});
