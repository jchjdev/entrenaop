import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_editor_ui/device_recordings_panel.dart';

Map<String, dynamic> recording() => {
  'id': 'apple-recording',
  'scheduled_id': 'schedule',
  'provider': 'apple',
  'state': 'associated',
  'name': 'Carrera sintética',
  'started_at': '2026-11-03T10:00:00Z',
  'timer_seconds': 105,
  'distance_meters': 390,
  'details_incomplete': true,
  'intervals': [
    {'index': 1, 'timer_seconds': 90.35, 'distance_meters': 390},
    {'index': 2, 'timer_seconds': 14.65},
  ],
};

void main() {
  test('la distancia ausente conserva NULL y el orden no inventa series', () {
    final result = DeviceActivitySummary.fromJson(recording());
    expect(result.detailsIncomplete, isTrue);
    expect(result.intervals[0].seconds, 90.35);
    expect(result.intervals[1].meters, isNull);
    expect(result.executionId, isNull);
  });
  test('rechaza intervalos negativos o no finitos', () {
    for (final bad in [-1, double.nan, double.infinity]) {
      expect(
        () => DeviceActivityInterval.fromJson({
          'index': 1,
          'timer_seconds': 10,
          'distance_meters': bad,
        }),
        throwsFormatException,
      );
    }
  });
  testWidgets('las grabaciones son plegables y omiten la distancia que falta', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeviceRecordingsPanel(
              recordings: [DeviceActivitySummary.fromJson(recording())],
              detailsIncomplete: true,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.textContaining('Sesión realizada · Sin detalle por serie'),
      findsOneWidget,
    );
    expect(find.text('Intervalo 1'), findsNothing);
    await t.tap(find.text('Resultado recibido de Apple Watch'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('2 intervalos registrados'));
    await t.pumpAndSettle();
    await t.tap(find.text('2 intervalos registrados'));
    await t.pumpAndSettle();
    expect(find.text('Intervalo 1'), findsOneWidget);
    expect(find.text('1:30.35 · 390.0 m'), findsOneWidget);
    expect(find.text('0:14.65'), findsOneWidget);
    expect(find.text('0.0 m'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
