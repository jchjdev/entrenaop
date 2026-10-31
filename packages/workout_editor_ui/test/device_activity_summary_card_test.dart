import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_core/device_training_progress.dart';
import 'package:workout_editor_ui/device_activity_summary_card.dart';
import 'package:workout_editor_ui/device_training_progress_tile.dart';

void main() {
  final result = DeviceActivitySummary.fromJson({
    'id': 'activity',
    'scheduled_id': 'appointment',
    'name': 'Carrera',
    'started_at': '2026-10-31T10:00:00Z',
    'timer_seconds': 87.3,
    'state': 'test',
  });
  testWidgets(
    'Muestra minutos y segundos, pliega detalles y oculta mediciones ausentes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeviceActivitySummaryCard(result: result)),
        ),
      );
      expect(find.text('1:27'), findsOneWidget);
      expect(find.textContaining('FC media'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(
        find.textContaining('se conserva', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Actividad identificada como prueba'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Una pauta Apple no exige conectar Garmin para consultar sus datos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceTrainingProgressTile(
              progress: DeviceTrainingProgress(
                id: 'appointment',
                name: 'Carrera',
                date: '2026-10-31',
                phase: DeviceTrainingPhase.blocked,
                reason: 'connection_required',
                appleResults: [result],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Prueba · no completa la sesión'), findsOneWidget);
      expect(find.text('Envío bloqueado'), findsNothing);
    },
  );
}
