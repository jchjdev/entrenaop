import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_result_review.dart';
import 'package:workout_editor_ui/workout_execution_summary.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    for (final light in [false, true]) {
      testWidgets(
        'resumen a $width, claro=$light, texto 2× distingue datos ausentes',
        (t) async {
          t.view.physicalSize = Size(width, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          await t.pumpWidget(
            MaterialApp(
              theme: light ? EntrenaTheme.light : EntrenaTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WorkoutExecutionSummary(
                    review: reviewSessionFromJson({
                      'workout_execution_sets': [
                        {
                          'block_format': 'straight_sets',
                          'status': 'completed',
                          'target_reps': 10,
                          'actual_reps': 8,
                        },
                        {
                          'block_format': 'straight_sets',
                          'status': 'completed',
                          'target_reps': 10,
                        },
                      ],
                    }),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('1 con diferencias medidas'), findsOneWidget);
          expect(find.text('1 sin medidas suficientes'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
