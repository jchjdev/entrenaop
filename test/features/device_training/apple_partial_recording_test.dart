import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_core/running_step.dart';
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
    {
      'index': 1,
      'timer_seconds': 90.35,
      'distance_meters': 390,
      'phase_kind': 'run',
      'phase_source': 'prescription',
      'pace_relevant': true,
    },
    {'index': 2, 'timer_seconds': 14.65},
  ],
};

void main() {
  test('el descanso y las fases desconocidas no generan ritmos', () {
    for (final kind in [null, RunningStepKind.rest, RunningStepKind.recovery]) {
      expect(
        DeviceActivityInterval(
          index: 1,
          seconds: 60,
          meters: 12,
          phaseKind: kind,
          paceRelevant: kind != RunningStepKind.recovery,
        ).paceSecondsPerKm,
        isNull,
      );
    }
    expect(
      const DeviceActivityInterval(
        index: 1,
        seconds: 60,
        meters: 200,
        phaseKind: RunningStepKind.recovery,
        paceRelevant: true,
      ).paceSecondsPerKm,
      300,
    );
    expect(
      DeviceActivityInterval.fromJson({
        'index': 1,
        'timer_seconds': 60,
        'distance_meters': 12,
        'phase_kind': 'unknown_future_type',
        'pace_relevant': true,
      }).paceSecondsPerKm,
      isNull,
    );
  });
  testWidgets('distingue recuperación, carrera y fase dudosa sin ritmo falso', (
    t,
  ) async {
    final row = recording();
    row['intervals'] = <Map<String, dynamic>>[
      ...row['intervals'] as List,
      {
        'index': 3,
        'timer_seconds': 60,
        'distance_meters': 12,
        'phase_kind': 'recovery',
        'phase_source': 'prescription',
        'pace_relevant': false,
      },
      {
        'index': 4,
        'timer_seconds': 60,
        'distance_meters': 200,
        'phase_kind': 'recovery',
        'phase_source': 'prescription',
        'pace_relevant': true,
      },
    ];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeviceRecordingsPanel(
              recordings: [DeviceActivitySummary.fromJson(row)],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Resultado recibido de Apple Watch'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('4 fases registradas'));
    await t.tap(find.text('4 fases registradas'));
    await t.pumpAndSettle();
    expect(find.text('3. Recuperación'), findsOneWidget);
    expect(find.text('2. Fase sin identificar'), findsOneWidget);
    expect(find.text('1:00 · 12.0 m'), findsOneWidget);
    expect(find.text('1:00 · 200.0 m · Ritmo 5:00/km'), findsOneWidget);
    expect(find.textContaining('Ritmo 83:'), findsNothing);
    expect(t.takeException(), isNull);
  });
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
    expect(find.text('1. Carrera'), findsNothing);
    await t.tap(find.text('Resultado recibido de Apple Watch'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('2 fases registradas'));
    await t.pumpAndSettle();
    await t.tap(find.text('2 fases registradas'));
    await t.pumpAndSettle();
    expect(find.text('1. Carrera'), findsOneWidget);
    expect(find.text('1:30.35 · 390.0 m · Ritmo 3:52/km'), findsOneWidget);
    expect(find.text('0:14.65'), findsOneWidget);
    expect(find.text('0.0 m'), findsNothing);
    expect(t.takeException(), isNull);
  });
  test(
    'el ritmo usa los metros reales, conserva ausencias y redondea el minuto',
    () {
      expect(
        const DeviceActivityInterval(
          index: 1,
          seconds: 90.35,
          meters: 390,
          phaseKind: RunningStepKind.run,
          paceRelevant: true,
        ).paceSecondsPerKm,
        closeTo(231.6666667, .0001),
      );
      for (final meters in [null, 0.0, -1.0, double.nan, double.infinity]) {
        expect(
          DeviceActivityInterval(
            index: 1,
            seconds: 90,
            meters: meters,
          ).paceSecondsPerKm,
          isNull,
        );
      }
      expect(
        const DeviceActivityInterval(
          index: 1,
          seconds: 59.96,
          meters: 1000,
          phaseKind: RunningStepKind.run,
          paceRelevant: true,
        ).paceSecondsPerKm,
        59.96,
      );
    },
  );
  testWidgets('el resumen también muestra su ritmo y evita segundos 60', (
    t,
  ) async {
    final row = recording()..['timer_seconds'] = 59.96;
    row['distance_meters'] = 1000;
    row['intervals'] = [
      {
        'index': 1,
        'timer_seconds': 59.96,
        'distance_meters': 1000,
        'phase_kind': 'run',
        'phase_source': 'prescription',
        'pace_relevant': true,
      },
    ];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeviceRecordingsPanel(
              recordings: [DeviceActivitySummary.fromJson(row)],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Resultado recibido de Apple Watch'));
    await t.pumpAndSettle();
    expect(find.text('Ritmo medio calculado: 1:00/km'), findsOneWidget);
    await t.ensureVisible(find.text('1 fase registrada'));
    await t.pumpAndSettle();
    await t.tap(find.text('1 fase registrada'));
    await t.pumpAndSettle();
    expect(find.text('0:59.96 · 1000.0 m · Ritmo 1:00/km'), findsOneWidget);
    expect(find.textContaining('0:60/km'), findsNothing);
  });
}
