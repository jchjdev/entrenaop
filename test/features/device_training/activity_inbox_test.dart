import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_activity_summary.dart';

void main() {
  final row = <String, dynamic>{
    'id': 'measurement',
    'scheduled_id': null,
    'provider': 'garmin',
    'state': 'unassigned',
    'name': 'Carrera sintética',
    'started_at': '2026-10-20T08:00:00Z',
    'timer_seconds': 120.125,
    'distance_meters': 420.25,
    'interval_count': 3,
  };
  test('recibir una actividad no fabrica una pauta ni una ejecución', () {
    final result = DeviceActivitySummary.fromJson(row);
    expect(result.scheduledId, isNull);
    expect(result.executionId, isNull);
    expect(result.provider, 'garmin');
    expect(result.seconds, 120.125);
    expect(result.meters, 420.25);
    expect(result.averageHeartRate, isNull);
  });
  test(
    'una asociación exige pauta y la bandeja no admite una asociación ficticia',
    () {
      expect(
        () => DeviceActivitySummary.fromJson({...row, 'state': 'associated'}),
        throwsFormatException,
      );
      expect(
        () => DeviceActivitySummary.fromJson({
          ...row,
          'scheduled_id': 'appointment',
        }),
        throwsFormatException,
      );
      expect(
        () => DeviceActivitySummary.fromJson({...row, 'provider': 'unknown'}),
        throwsFormatException,
      );
    },
  );
  test('el contrato Apple anterior mantiene su proveedor y su pauta', () {
    final apple = {...row, 'scheduled_id': 'appointment', 'state': 'review'}
      ..remove('provider');
    final result = DeviceActivitySummary.fromJson(apple);
    expect(result.provider, 'apple');
    expect(result.scheduledId, 'appointment');
  });
}
