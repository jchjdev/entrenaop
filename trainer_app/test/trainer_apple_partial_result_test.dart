import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/professional_workout_result.dart';

void main() {
  testWidgets(
    'Trainer muestra Apple parcial sin declarar series omitidas ni valorar la pauta',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerWorkoutResultContent(
              result: {
                'id': 'execution',
                'template_name': 'Carrera de prueba',
                'template_version': 1,
                'status': 'completed',
                'started_at': '2026-11-03T10:00:00Z',
                'device_details_incomplete': true,
                'observed_timer_seconds': 105,
                'observed_distance_meters': 390,
                'device_results': [
                  {
                    'id': 'apple-result',
                    'scheduled_id': 'schedule',
                    'name': 'Carrera de prueba',
                    'started_at': '2026-11-03T10:00:00Z',
                    'state': 'associated',
                    'provider': 'apple',
                    'timer_seconds': 105,
                    'distance_meters': 390,
                    'execution_id': 'execution',
                    'details_incomplete': true,
                    'intervals': [
                      {
                        'index': 1,
                        'timer_seconds': 90.0,
                        'distance_meters': 390,
                      },
                      {'index': 2, 'timer_seconds': 15.0},
                    ],
                  },
                ],
                'workout_execution_sets': [
                  {
                    'id': 'set',
                    'status': 'pending',
                    'block_order': 0,
                    'item_order': 0,
                    'set_order': 1,
                    'block_format': 'running',
                    'block_name': 'Carrera',
                    'exercise_name': 'Carrera',
                    'exercise_id': 'run',
                    'target_distance_meters': 400,
                  },
                ],
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Sesión realizada · Sin detalle por serie'),
        findsOneWidget,
      );
      expect(
        find.text('Resultados incorporados de Apple Watch'),
        findsOneWidget,
      );
      expect(find.textContaining('0 series completadas'), findsNothing);
      expect(find.textContaining('Pautado:'), findsNothing);
      expect(find.text('Solo diferencias con la pauta'), findsNothing);
      await t.ensureVisible(
        find.text('Resultados incorporados de Apple Watch'),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Resultados incorporados de Apple Watch'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('2 fases registradas'));
      await t.pumpAndSettle();
      await t.tap(find.text('2 fases registradas'));
      await t.pumpAndSettle();
      expect(find.text('2. Fase sin identificar'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
