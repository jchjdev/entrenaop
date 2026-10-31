import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_result_review.dart';

Map<String, dynamic> row(Map<String, dynamic> values) => {
  'block_format': 'straight_sets',
  'status': 'completed',
  'target_reps': 10,
  'actual_reps': 10,
  ...values,
};
ReviewExecutionSummary summary(
  List<Map<String, dynamic>> sets, {
  List<Map<String, dynamic>> amrap = const [],
}) => ReviewExecutionSummary(
  reviewSessionFromJson({
    'workout_execution_sets': sets,
    'workout_amrap_results': amrap,
  }),
);

void main() {
  test(
    'separa diferencias medidas, ausencias, omisiones y registros pendientes',
    () {
      final value = summary([
        row({}),
        row({'actual_reps': 8}),
        row({'actual_reps': null}),
        row({'status': 'skipped'}),
        row({'status': 'pending'}),
      ]);
      expect(value.total, 5);
      expect(value.completed, 3);
      expect(value.matching, 1);
      expect(value.different, 1);
      expect(value.missing, 1);
      expect(value.skipped, 1);
      expect(value.pending, 1);
    },
  );
  test('cero repeticiones es una medida; no equivale a una ausencia', () {
    final value = summary([
      row({'actual_reps': 0}),
    ]);
    expect(value.different, 1);
    expect(value.missing, 0);
  });
  test(
    'sin referencia no se inventa cumplimiento; tampoco con NaN o infinito',
    () {
      final value = summary([
        row({'target_reps': null}),
        row({'actual_reps': double.nan}),
        row({'actual_reps': double.infinity}),
      ]);
      expect(value.withoutReference, 1);
      expect(value.missing, 2);
      expect(value.matching, 0);
    },
  );
  test('ritmos y recuperaciones usan las tolerancias y el temporizador ya acordados', () {
    final value = summary([
      {
        'block_format': 'running',
        'status': 'completed',
        'target_distance_meters': 400,
        'target_pace_min_seconds_per_km': 215,
        'target_pace_max_seconds_per_km': 220,
        'recovery_duration_seconds': 50,
        'actual_distance_meters': 400,
        'actual_duration_seconds': 120,
        'actual_recovery_duration_seconds': 80,
        'result_source': 'device',
        'observed_duration_seconds': 87.6,
        'observed_recovery_duration_seconds': 52,
      },
      {
        'block_format': 'running',
        'status': 'completed',
        'target_distance_meters': 400,
        'target_pace_min_seconds_per_km': 215,
        'target_pace_max_seconds_per_km': 220,
        'actual_duration_seconds': 87.6,
      },
    ]);
    expect(value.matching, 1);
    expect(value.missing, 1);
    expect(value.different, 0);
  });
  test(
    'las condiciones sin confirmar se mantienen separadas de las diferencias',
    () {
      final value = summary([
        {
          'block_format': 'straight_sets',
          'status': 'completed',
          'performance_prescription': {
            'measurement': 'REPS',
            'target_value': 10,
          },
          'performance_result': {'value': 8, 'technique_valid': false},
        },
      ]);
      expect(value.uncertain, 1);
      expect(value.different, 0);
      expect(value.matching, 0);
    },
  );
  test('AMRAP cuenta bloques con rondas, sin convertir su receta en series realizadas', () {
    final value = summary(
      [
        row({'block_format': 'amrap', 'block_order': 0}),
        row({'block_format': 'amrap', 'block_order': 0, 'status': 'pending'}),
        row({'block_format': 'amrap', 'block_order': 1}),
      ],
      amrap: [
        {'block_order': 0, 'completed_rounds': 3, 'partial_reps': 0},
      ],
    );
    expect(value.total, 0);
    expect(value.completed, 0);
    expect(value.amrapResults, 1);
    expect(value.amrapWithoutResult, 1);
  });
  test('un resultado vacío no fabrica posiciones, rondas ni cumplimiento', () {
    final value = summary([]);
    expect(value.total, 0);
    expect(value.matching, 0);
    expect(value.amrapResults, 0);
  });
}
