import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/running_pace_analysis.dart';
import 'package:workout_editor_ui/running_pace_chart.dart';

import '../../../helpers/performance_visual_review.dart';
import '../domain/running_pace_analysis_test.dart' show paceRow;

void main() {
  setUpAll(loadReviewFont);
  for (final scenario in [(1200.0, false), (1200.0, true), (390.0, false)]) {
    testWidgets('revisión visual del gráfico real: $scenario', (t) async {
      t.view.physicalSize = Size(scenario.$1, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final analysis = RunningPaceAnalysis.fromRows([
        paceRow(
          0,
          kind: 'warmup',
          distance: 2068.3,
          observed: 839.49,
          min: null,
          max: null,
        ),
        for (final pair in [
          87.32,
          87.14,
          88.28,
          null,
          87.50,
          88.06,
          86.90,
        ].indexed)
          paceRow(
            pair.$1 + 1,
            observed: pair.$2,
            status: pair.$2 == null ? 'skipped' : 'completed',
          ),
        paceRow(
          9,
          kind: 'cooldown',
          distance: 1000,
          observed: 420,
          min: null,
          max: null,
        ),
      ]);
      await t.pumpWidget(
        MaterialApp(
          theme: scenario.$2 ? EntrenaTheme.light : EntrenaTheme.dark,
          home: Scaffold(
            appBar: AppBar(title: const Text('Resultados · Series de 400 m')),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: const ValueKey('review-boundary'),
                  child: RunningPaceChart(analysis: analysis),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('6 de 7'), findsOneWidget);
      await capturePerformanceWidget(
        t,
        'running-pace-${scenario.$1.toInt()}-${scenario.$2 ? 'light' : 'dark'}',
      );
    });
  }
}
