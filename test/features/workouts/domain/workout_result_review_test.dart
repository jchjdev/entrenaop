import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_result_review.dart';

Map<String, dynamic> reviewRow({
  String id = 'set',
  int order = 0,
  String exercise = 'bench',
  String status = 'completed',
  num? actualReps = 5,
  num? load = 20,
}) => {
  'id': id,
  'block_order': 0,
  'item_order': 0,
  'set_order': order,
  'exercise_id': exercise,
  'exercise_name': 'Press',
  'block_name': 'Principal',
  'block_format': 'straight_sets',
  'status': status,
  'target_reps': 5,
  'actual_reps': actualReps,
  'target_load_kg': 20,
  'actual_load_kg': load,
};
ReviewSession reviewSession(
  List<Map<String, dynamic>> sets, {
  String id = 'now',
  String template = 'template',
  int version = 1,
  int day = 24,
  String status = 'completed',
}) => reviewSessionFromJson({
  'id': id,
  'template_id': template,
  'template_version': version,
  'template_name': 'Fuerza',
  'started_at': DateTime.utc(2026, 10, day).toIso8601String(),
  'status': status,
  'workout_execution_sets': sets,
});
void main() {
  test('protocolo o montaje distinto no empareja variantes aunque coincida ejercicio', () {
    final a = reviewRow()
      ..['performance_prescription'] = {
        'measurement': 'LOAD_REPS',
        'setup_key': 'flat',
        'target_value': 5,
      };
    final b = reviewRow()
      ..['performance_prescription'] = {
        'measurement': 'LOAD_REPS',
        'setup_key': 'inclined',
        'target_value': 5,
      };
    expect(
      compareReviewSessions(
        reviewSession([a]),
        reviewSession([b], id: 'old', day: 23),
      ).single.previous,
      isNull,
    );
  });

  test('la pauta cumplida no incluye el tiempo incidental como diferencia', () {
    expect(
      reviewSetFromJson(reviewRow()..['observed_duration_seconds'] = 4.665)
          .needsReview,
      isFalse,
    );
  });
  test('kilos ausentes no equivalen a cero o al objetivo', () {
    final set = reviewSetFromJson(reviewRow(load: null));
    expect(set.needsReview, isTrue);
    expect(set.actual.containsKey('load'), isFalse);
  });
  test('omisiones, pendientes y RIR diferente permanecen en revisión', () {
    for (final status in ['pending', 'skipped']) {
      expect(reviewSetFromJson(reviewRow(status: status)).needsReview, isTrue);
    }
    expect(
      reviewSetFromJson(reviewRow()..addAll({'target_rir': 2, 'actual_rir': 1}))
          .needsReview,
      isTrue,
    );
  });
  test(
    'carrera usa precisión nativa, márgenes de tiempo y límites de ritmo',
    () {
      final row = reviewRow()
        ..remove('target_reps')
        ..remove('target_load_kg')
        ..addAll({
          'block_format': 'running',
          'actual_duration_seconds': 88,
          'observed_duration_seconds': 87.3,
          'result_source': 'device',
          'actual_distance_meters': 400,
          'target_distance_meters': 400,
          'target_pace_min_seconds_per_km': 215,
          'target_pace_max_seconds_per_km': 220,
        });
      expect(reviewSetFromJson(row).needsReview, isFalse);
      row['observed_duration_seconds'] = 89;
      expect(reviewSetFromJson(row).needsReview, isTrue);
      row['result_source'] = 'manual';
      expect(reviewSetFromJson(row).actual['time'], 88);
    },
  );
  test('AMRAP conserva la receta y no simula series', () {
    expect(
      reviewSetFromJson(reviewRow()..['block_format'] = 'amrap').needsReview,
      isTrue,
    );
  });
  test('solo misma sesión versión anterior cerrada', () {
    final current = reviewSession([reviewRow()]);
    for (final older in [
      reviewSession([reviewRow()], id: 'old', version: 2, day: 23),
      reviewSession([reviewRow()], id: 'old', template: 'other', day: 23),
      reviewSession([reviewRow()], id: 'old', day: 25),
      reviewSession([reviewRow()], id: 'old', day: 23, status: 'in_progress'),
    ]) {
      expect(compareReviewSessions(current, older), isEmpty);
    }
  });
  test('mismo nombre no empareja otra variante o posición', () {
    final older = reviewSession(
      [reviewRow(exercise: 'other')],
      id: 'old',
      day: 23,
    );
    expect(
      compareReviewSessions(
        reviewSession([reviewRow()]),
        older,
      ).single.previous,
      isNull,
    );
  });
  test('identidades repetidas no emparejan arbitrariamente', () {
    final older = reviewSession(
      [reviewRow(), reviewRow(id: 'duplicate')],
      id: 'old',
      day: 23,
    );
    expect(
      compareReviewSessions(
        reviewSession([reviewRow()]),
        older,
      ).single.previous,
      isNull,
    );
  });
  test('cambio de pauta se señala sin alterar las marcas', () {
    final current = reviewSession([
      reviewRow(actualReps: 7)..['target_reps'] = 7,
    ]);
    final older = reviewSession([reviewRow()], id: 'old', day: 23);
    final pair = compareReviewSessions(current, older).single;
    expect(pair.changedPrescription, isTrue);
    expect(pair.current.actual['reps'], 7);
    expect(pair.previous!.actual['reps'], 5);
  });
  test('los objetos de lectura no admiten alterar las mediciones', () {
    final set = reviewSetFromJson(reviewRow());
    expect(() => set.actual['reps'] = 99, throwsUnsupportedError);
  });
}
