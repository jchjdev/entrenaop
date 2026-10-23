import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/data/supabase_activity_result_repository.dart';
import 'package:entrenaop/features/device_training/data/supabase_training_delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fuerza conserva kilos y repeticiones, bloquea descansos y registros incompletos', () {
    const row = LapAssignment(
      block: 0,
      item: 0,
      set: 0,
      label: 'Banca',
      requiresRecovery: false,
      strength: true,
      requiresReps: true,
      laps: [0],
    );
    const active = RecordedLap(
      0,
      30,
      0,
      'active',
      strength: true,
      repetitions: 9,
      loadKg: 22.5,
    );
    const rest = RecordedLap(1, 30, 0, 'rest', strength: true);
    expect(validLapAssignments([row], [active, rest]), isTrue);
    expect(validLapAssignments([row, row], [active, rest]), isFalse);
    expect(
      validLapAssignments(
        [
          row.select(laps: [1]),
        ],
        [active, rest],
      ),
      isFalse,
    );
    expect(
      validLapAssignments(
        [row],
        [const RecordedLap(0, 30, 0, 'active', strength: true)],
      ),
      isFalse,
    );
    expect(
      validLapAssignments(
        [row],
        [const RecordedLap(0, 30, 0, 'active', strength: true, repetitions: 9)],
      ),
      isTrue,
    );
  });
  test(
    'decodifica el deporte fuerza sin inventar distancia, carga ni ritmo',
    () {
      final result = decodeActivityReview({
        'activity_id': 'activity',
        'activity_revision': 'a',
        'scheduled_id': 'scheduled',
        'source_revision': 'b',
        'activity': {
          'sport': 'strength',
          'name': 'Fixture',
          'startedAt': '2026-10-20T08:00:00Z',
          'offsetSeconds': 7200,
          'timerSeconds': 90,
          'distanceMeters': null,
          'sets': [
            {
              'index': 0,
              'seconds': 30,
              'kind': 'active',
              'repetitions': 9,
              'loadKg': null,
            },
          ],
        },
        'rows': [
          {
            'block_order': 0,
            'item_order': 0,
            'set_order': 0,
            'label': 'Banca',
            'measure': 'reps',
            'requires_recovery': false,
            'lap_indices': [0],
            'recovery_lap_indices': [],
          },
        ],
      });
      expect(result.sport, 'strength');
      expect(result.laps.single.repetitions, 9);
      expect(result.laps.single.loadKg, isNull);
      expect(result.rows.single.requiresReps, isTrue);
      final preview = decodeTrainingPreview({
        'revision': 'a' * 64,
        'prescription': {
          'sport': 'strength',
          'name': 'Fixture',
          'date': '2026-10-24',
          'steps': [
            {
              'kind': 'strength',
              'measure': 'reps',
              'value': 10,
              'description': 'Banca',
              'loadKg': 22.5,
            },
          ],
        },
      });
      expect(preview.steps.single.loadKg, 22.5);
      expect(preview.steps.single.fast, isNull);
    },
  );
}
