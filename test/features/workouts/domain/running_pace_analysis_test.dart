import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/running_pace_analysis.dart';

Map<String, dynamic> paceRow(
  int order, {
  String? kind = 'run',
  String status = 'completed',
  int block = 0,
  num? distance = 400,
  num? time = 88,
  num? observed,
  num? targetDistance = 400,
  num? min = 215,
  num? max = 220,
  int recovery = 50,
  String? recoveryType = 'passive',
}) => {
  'id': '$block-$order',
  'block_order': block,
  'item_order': 0,
  'set_order': order,
  'block_format': 'running',
  'status': status,
  'exercise_id': 'run',
  'exercise_name': 'Carrera',
  'block_name': 'Series',
  'actual_distance_meters': distance,
  'actual_duration_seconds': time,
  'result_source': observed == null ? 'manual' : 'device',
  'observed_duration_seconds': observed,
  'target_distance_meters': targetDistance,
  'target_pace_min_seconds_per_km': min,
  'target_pace_max_seconds_per_km': max,
  'recovery_duration_seconds': recovery,
  'recovery_type': recoveryType,
  'actual_recovery_duration_seconds': 900,
  'actual_recovery_distance_meters': 999,
  if (kind != null)
    'running_step': {
      'schema_version': 2,
      'kind': kind,
      'completion': 'distance',
    },
};

void main() {
  test('usa tiempo medido y distancia real sin sumar la recuperación', () {
    final sample = RunningPaceAnalysis.fromRows([paceRow(0, observed: 87.32)])
        .samples
        .single;
    expect(sample.pace, closeTo(218.3, .000001));
    expect(sample.duration, 87.32);
  });

  test('media ponderada por distancia, no media aritmética de ritmos', () {
    final summary = RunningPaceSummary(
      RunningPaceAnalysis.fromRows([
        paceRow(0, distance: 400, time: 80),
        paceRow(1, distance: 1000, time: 240, targetDistance: 1000),
      ]).samples,
    );
    expect(summary.mean, closeTo(320 * 1000 / 1400, .000001));
    expect(summary.fastest!.review.id, '0-0');
    expect(summary.slowest!.review.id, '0-1');
  });

  test('ordena la receta y conserva el hueco de una repetición omitida', () {
    final samples = RunningPaceAnalysis.fromRows([
      paceRow(2),
      paceRow(0, status: 'skipped'),
      paceRow(1),
    ]).samples;
    expect(samples.map((s) => s.review.order), [0, 1, 2]);
    expect(samples.first.pace, isNull);
  });

  test(
    'calentamiento, enfriamiento y recuperación no son series de esfuerzo',
    () {
      final analysis = RunningPaceAnalysis.fromRows([
        paceRow(0, kind: 'warmup'),
        paceRow(1),
        paceRow(2, kind: 'recovery'),
        paceRow(3, kind: 'cooldown'),
      ]);
      expect(analysis.samples.where((s) => s.effort), hasLength(1));
      expect(analysis.groups, isEmpty);
    },
  );

  test(
    'registros antiguos y fases futuras se conservan sin atribuirles carrera',
    () {
      final analysis = RunningPaceAnalysis.fromRows([
        paceRow(0, kind: null),
        paceRow(1, kind: 'new_kind'),
      ]);
      expect(analysis.hasEfforts, isFalse);
      expect(analysis.hasUnclassified, isTrue);
      expect(analysis.samples, hasLength(2));
      expect(analysis.groups, isEmpty);
    },
  );

  for (final distance in <num?>[null, 0, -1, double.nan, double.infinity]) {
    test(
      'no sustituye por la distancia pautada una medición inválida: $distance',
      () {
        final analysis = RunningPaceAnalysis.fromRows([
          paceRow(0, distance: distance),
        ]);
        expect(analysis.samples.single.pace, isNull);
        expect(RunningPaceSummary(analysis.samples).mean, isNull);
      },
    );
  }

  test('sin tiempo o con serie incompleta no calcula ritmo aunque haya campos antiguos', () {
    final analysis = RunningPaceAnalysis.fromRows([
      paceRow(0, time: null),
      paceRow(1, status: 'in_progress'),
      paceRow(2, time: -10),
      paceRow(3, time: double.infinity),
    ]);
    expect(analysis.samples.every((s) => s.pace == null), isTrue);
  });

  test('regularidad separa distancia, objetivo, recuperación y bloque', () {
    final analysis = RunningPaceAnalysis.fromRows([
      paceRow(0, time: 87),
      paceRow(1, time: 88),
      paceRow(2, targetDistance: 800, distance: 800),
      paceRow(3, min: 230, max: 240),
      paceRow(4, recovery: 60),
      paceRow(5, recoveryType: 'active'),
      paceRow(6, block: 1),
      paceRow(7, distance: 200),
      paceRow(8, min: null, max: null),
    ]);
    final group = analysis.groups.single;
    expect(group.samples.map((s) => s.review.id), ['0-0', '0-1']);
    expect(group.spread, 2.5);
    expect(group.firstLastDelta, 2.5);
  });

  test(
    'el grupo más numeroso se propone primero y conserva el orden en empates',
    () {
      final analysis = RunningPaceAnalysis.fromRows([
        paceRow(0, block: 0),
        paceRow(1, block: 0),
        paceRow(0, block: 1),
        paceRow(1, block: 1),
        paceRow(2, block: 1),
      ]);
      expect(analysis.groups.map((g) => g.samples.length), [3, 2]);
    },
  );

  test('una franja inválida y los bloques de fuerza no entran al análisis', () {
    final analysis = RunningPaceAnalysis.fromRows([
      paceRow(0, min: 230, max: 220),
      {...paceRow(1), 'block_format': 'straight_sets'},
    ]);
    expect(analysis.samples, hasLength(1));
    expect(analysis.samples.single.hasTarget, isFalse);
    expect(analysis.groups, isEmpty);
  });
}
