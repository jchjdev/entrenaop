import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';

Map<String, dynamic> runningResult({
  String status = 'completed',
  String source = 'device',
  num? distance = 400,
  num? duration = 88,
  num? observed = 87.32,
}) => {
  'id': 'execution',
  'template_id': 'template',
  'template_name': 'Series de 400 m',
  'template_version': 1,
  'status': 'completed',
  'started_at': '2026-10-30T10:00:00Z',
  'workout_execution_sets': [
    {
      'id': 'series',
      'block_order': 0,
      'item_order': 0,
      'set_order': 1,
      'block_format': 'running',
      'block_name': 'Carrera',
      'exercise_name': 'Carrera',
      'exercise_id': 'run',
      'status': status,
      'target_distance_meters': 400,
      'target_pace_min_seconds_per_km': 215,
      'target_pace_max_seconds_per_km': 220,
      'actual_distance_meters': distance,
      'actual_duration_seconds': duration,
      'observed_duration_seconds': observed,
      'result_source': source,
      'actual_recovery_duration_seconds': 50,
      'actual_recovery_distance_meters': 42.66,
    },
  ],
};

Future<void> mount(WidgetTester t, Map<String, dynamic> result) async {
  await t.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: Scaffold(body: TrainerWorkoutResultContent(result: result)),
    ),
  );
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.textContaining(RegExp(r'^Pautado:')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('ritmo de la serie usa el tiempo medido, sin recuperaciones', (
    t,
  ) async {
    await mount(t, runningResult());
    expect(
      find.textContaining('1:27.32 · ritmo medio 3:38/km'),
      findsOneWidget,
    );
    expect(find.textContaining('recuperación 0:50'), findsOneWidget);
  });
  testWidgets('registro manual usa su duración y su distancia reales', (
    t,
  ) async {
    await mount(
      t,
      runningResult(source: 'manual', distance: 500, duration: 100),
    );
    expect(find.textContaining('ritmo medio 3:20/km'), findsOneWidget);
  });
  testWidgets('redondear el ritmo conserva el cambio de minuto', (t) async {
    await mount(t, runningResult(distance: 1000, observed: 59.96));
    expect(find.textContaining('ritmo medio 1:00/km'), findsOneWidget);
  });
  for (final distance in [null, 0, -1]) {
    testWidgets('no usa la distancia pautada cuando la real es $distance', (
      t,
    ) async {
      await mount(t, runningResult(distance: distance));
      expect(find.textContaining('ritmo medio'), findsNothing);
    });
  }
  testWidgets('sin duración medida ni registrada no inventa ritmo', (t) async {
    await mount(t, runningResult(duration: null, observed: null));
    expect(find.textContaining('ritmo medio'), findsNothing);
  });
  for (final status in ['planned', 'in_progress', 'skipped']) {
    testWidgets('no presenta ritmo realizado en una serie $status', (t) async {
      await mount(t, runningResult(status: status));
      expect(find.textContaining('ritmo medio'), findsNothing);
    });
  }
}
