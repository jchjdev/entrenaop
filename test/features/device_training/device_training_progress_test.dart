import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_training_progress.dart';

void main() {
  Map<String, dynamic> result(String provider) => {
    'id': provider,
    'scheduled_id': 'appointment',
    'provider': provider,
    'name': 'Carrera sintética',
    'state': provider == 'garmin' ? 'review' : 'associated',
    'started_at': '2026-10-20T08:00:00Z',
    'timer_seconds': 120.5,
    'distance_meters': 400,
  };
  Map<String, dynamic> progress() => {
    'id': 'appointment',
    'name': 'Carrera sintética',
    'date': '2026-10-20',
    'state': 'sent',
    'results_confirmed': false,
    'has_delivery': true,
  };

  test('lee ambos proveedores sin confirmar ni completar la pauta', () {
    final value = DeviceTrainingProgress.fromJson({
      ...progress(),
      'device_results': [result('apple'), result('garmin')],
      'apple_results': [result('apple')],
    });
    expect(value.deviceResults.map((r) => r.provider), ['apple', 'garmin']);
    expect(value.deviceResults.last.state, 'review');
    expect(value.resultsConfirmed, isFalse);
    expect(value.executionId, isNull);
    expect(value.phase, DeviceTrainingPhase.sent);
  });

  test('admite la proyección anterior durante el despliegue', () {
    final value = DeviceTrainingProgress.fromJson({
      ...progress(),
      'apple_results': [result('apple')],
    });
    expect(value.deviceResults.single.provider, 'apple');
  });

  test('el campo común vacío prevalece sobre el campo antiguo', () {
    final value = DeviceTrainingProgress.fromJson({
      ...progress(),
      'device_results': [],
      'apple_results': [result('apple')],
    });
    expect(value.deviceResults, isEmpty);
  });
}
