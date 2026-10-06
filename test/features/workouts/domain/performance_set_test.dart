import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_set.dart';
import 'package:workout_core/performance_set_codec.dart';

PerformanceSetPrescription prescription(String mode) =>
    PerformanceSetPrescription(
      exerciseCode: 'example',
      exerciseVersion: 1,
      protocolKey: 'exam',
      protocolVersion: 2,
      setupKey: 'same',
      measurement: mode,
      loadMode: 'bodyweight',
      policyVersion: 'v1',
      targetValue: 8,
    );

void main() {
  test('el protocolo conserva sus capacidades sin convertir un circuito fijo en reactivo', () {
    final json = <String, dynamic>{
      'schema_version': 1,
      'exercise_code': 'slalom_ball_course_16m',
      'exercise_version': 1,
      'protocol_key': 'fixture',
      'protocol_version': 1,
      'setup_key': 'fixture',
      'measurement': 'TIME_FOR_COURSE',
      'load_mode': 'bodyweight',
      'policy_version': 'performance_v1_1',
      'target_value': 13.25,
      'intent': 'practice',
    };
    final fixed = PerformanceSetCodec.prescription(json);
    expect(fixed.recordsStimulusResponses, isFalse);
    expect(fixed.recordsPenaltySeconds, isFalse);
    final oldReactive = PerformanceSetCodec.prescription({
      ...json,
      'exercise_code': 'reactive_direction_drill',
    });
    expect(oldReactive.recordsStimulusResponses, isTrue);
    final explicit = PerformanceSetCodec.prescription({
      ...json,
      'records_stimulus_responses': true,
      'records_penalty_seconds': true,
    });
    expect(explicit.recordsStimulusResponses, isTrue);
    expect(explicit.recordsPenaltySeconds, isTrue);
    expect(explicit, isNot(fixed));
  });
  test('mantiene ausencia, decimal e intento nulo al serializar', () {
    const r = PerformanceSetResult(value: 8.125, techniqueValid: false);
    final copy = PerformanceSetCodec.result(
      PerformanceSetCodec.encodeResult(r),
    );
    expect(copy, r);
    expect(copy.rir, isNull);
    expect(copy.conditionsConfirmed, isNull);
    expect(copy.validate(prescription('TIME_FOR_COURSE')), isNull);
  });
  test('las mediciones no heredan el RIR de las repeticiones', () {
    for (final mode in [
      'DURATION',
      'TIME_FOR_COURSE',
      'TIME_FOR_DISTANCE',
      'DISTANCE',
      'HEIGHT',
      'MAX_LOAD',
      'PASS_FAIL',
      'REACTIVE_METRICS',
    ]) {
      expect(
        const PerformanceSetResult(rir: 3).validate(prescription(mode)),
        isNotNull,
      );
    }
    expect(
      const PerformanceSetResult(rir: 3).validate(prescription('REPS')),
      isNull,
    );
  });
  test('distingue intentos, repeticiones y decimales medidos', () {
    expect(
      const PerformanceSetResult(value: 2.3).validate(prescription('REPS')),
      isNotNull,
    );
    expect(
      const PerformanceSetResult(value: 2.3).validate(prescription('DISTANCE')),
      isNull,
    );
    expect(
      const PerformanceSetResult(value: 2).validate(prescription('PASS_FAIL')),
      isNotNull,
    );
    expect(
      const PerformanceSetResult(value: double.nan)
          .validate(prescription('HEIGHT')),
      isNotNull,
    );
    expect(
      const PerformanceSetResult(value: double.infinity)
          .validate(prescription('HEIGHT')),
      isNotNull,
    );
  });
  test('no inventa capacidad reactiva a partir de un tiempo de circuito', () {
    const r = PerformanceSetResult(
      value: 0.7,
      correctResponses: 3,
      totalResponses: 4,
    );
    expect(r.validate(prescription('TIME_FOR_COURSE')), isNull);
    expect(r.validate(prescription('REACTIVE_METRICS')), isNotNull);
    expect(
      const PerformanceSetResult(
        correctResponses: 5,
        totalResponses: 4,
      ).validate(prescription('REACTIVE_METRICS')),
      isNotNull,
    );
  });
}
