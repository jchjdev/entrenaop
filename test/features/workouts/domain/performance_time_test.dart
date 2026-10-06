import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_time.dart';
import 'package:workout_core/performance_set.dart';
import 'package:workout_core/performance_set_codec.dart';

void main() {
  test(
    'tiempos humanos preservan segundos y fracciones sin aceptar errores',
    () {
      expect(parsePerformanceTime('7:10'), 430);
      expect(formatPerformanceTime(430), '7:10');
      expect(parsePerformanceTime('13,25'), 13.25);
      expect(parsePerformanceTime('1:03,25'), 63.25);
      for (final invalid in ['1:60', '-1', 'NaN', '1:2:3', '1.5:00']) {
        expect(parsePerformanceTime(invalid), isNull, reason: invalid);
      }
    },
  );
  test(
    'isometría usa RPE y conserva el contrato de repeticiones histórico',
    () {
      final p = PerformanceSetCodec.prescription({
        'schema_version': 1,
        'exercise_code': 'front_plank_forearms',
        'exercise_version': 1,
        'protocol_key': 'fixture',
        'protocol_version': 1,
        'setup_key': 'standard:fixture',
        'measurement': 'DURATION',
        'load_mode': 'bodyweight',
        'policy_version': 'performance_v2',
        'target_value': 27,
        'intent': 'work',
        'effort_mode': 'rpe',
        'target_rpe': 7,
      });
      expect(p.usesRpe, isTrue);
      expect(p.usesRir, isFalse);
      expect(const PerformanceSetResult(rpe: 7).validate(p), isNull);
      expect(const PerformanceSetResult(rpe: 11).validate(p), isNotNull);
      expect(const PerformanceSetResult(rir: 3).validate(p), isNotNull);
      expect(
        PerformanceSetCodec.result(
          PerformanceSetCodec.encodeResult(const PerformanceSetResult(rpe: 6)),
        ).rpe,
        6,
      );
      expect(const PerformanceSetResult().rpe, isNull);
    },
  );
}
