import 'performance_set.dart';

class PerformanceSetCodec {
  const PerformanceSetCodec._();
  static PerformanceSetPrescription prescription(Map<String, dynamic> j) {
    if (j['schema_version'] != 1) {
      throw const FormatException('Versión de prescripción no compatible.');
    }
    return PerformanceSetPrescription(
      exerciseCode: j['exercise_code'] as String,
      exerciseVersion: j['exercise_version'] as int,
      protocolKey: j['protocol_key'] as String,
      protocolVersion: j['protocol_version'] as int,
      setupKey: j['setup_key'] as String,
      measurement: j['measurement'] as String,
      loadMode: j['load_mode'] as String,
      policyVersion: j['policy_version'] as String,
      targetValue: (j['target_value'] as num).toDouble(),
      intent: j['intent'] as String,
      fixedDurationSeconds: _number(j['fixed_duration_seconds']),
      fixedDistanceMeters: _number(j['fixed_distance_meters']),
      externalLoadKg: _number(j['external_load_kg']),
      bodyMassKg: _number(j['body_mass_kg']),
      targetRir: _number(j['target_rir']),
      effortMode: j['effort_mode'] as String?,
      targetRpe: _number(j['target_rpe']),
      stimulusCode: j['stimulus_code'] as String?,
      instructions: j['instructions'] as String? ?? '',
      // Compatibilidad con el único perfil reactivo v1 anterior a estos campos.
      recordsStimulusResponses:
          j['records_stimulus_responses'] as bool? ??
          (j['exercise_code'] == 'reactive_direction_drill' &&
              j['exercise_version'] == 1 &&
              const [
                'TIME_FOR_COURSE',
                'PASS_FAIL',
              ].contains(j['measurement'])),
      recordsPenaltySeconds: j['records_penalty_seconds'] as bool? ?? false,
    );
  }

  static PerformanceSetResult result(Map<String, dynamic> j) =>
      PerformanceSetResult(
        value: _number(j['value']),
        techniqueValid: j['technique_valid'] as bool?,
        conditionsConfirmed: j['conditions_confirmed'] as bool?,
        tolerated: j['tolerated'] as bool?,
        rir: _number(j['rir']),
        rpe: _number(j['rpe']),
        loadKg: _number(j['load_kg']),
        bodyMassKg: _number(j['body_mass_kg']),
        penaltySeconds: _number(j['penalty_seconds']),
        correctResponses: j['correct_responses'] as int?,
        totalResponses: j['total_responses'] as int?,
        succeeded: j['succeeded'] as bool?,
        actualDurationSeconds: _number(j['actual_duration_seconds']),
        jumpHeightMeters: _number(j['jump_height_meters']),
        measurementMethod: j['measurement_method'] as String?,
        stopReason: j['stop_reason'] as String? ?? 'unknown',
      );

  static Map<String, dynamic> encodeResult(PerformanceSetResult r) => {
    'value': r.value,
    'technique_valid': r.techniqueValid,
    'conditions_confirmed': r.conditionsConfirmed,
    'tolerated': r.tolerated,
    'rir': r.rir,
    if (r.rpe != null) 'rpe': r.rpe,
    'load_kg': r.loadKg,
    'body_mass_kg': r.bodyMassKg,
    'penalty_seconds': r.penaltySeconds,
    'correct_responses': r.correctResponses,
    'total_responses': r.totalResponses,
    'succeeded': r.succeeded,
    'actual_duration_seconds': r.actualDurationSeconds,
    'jump_height_meters': r.jumpHeightMeters,
    'measurement_method': r.measurementMethod,
    'stop_reason': r.stopReason,
  };
  static double? _number(Object? v) => (v as num?)?.toDouble();
}
