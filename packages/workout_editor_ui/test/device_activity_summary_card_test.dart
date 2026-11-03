import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_activity_summary.dart';
import 'package:workout_core/device_training_progress.dart';
import 'package:workout_editor_ui/device_activity_summary_card.dart';
import 'package:workout_editor_ui/device_training_progress_tile.dart';

void main() {
  testWidgets(
    'muestra Apple y Garmin pendientes en la misma pauta sin anunciar cierre',
    (tester) async {
      final progress = DeviceTrainingProgress.fromJson({
        'id': 'appointment',
        'name': 'Carrera sintética',
        'date': '2026-10-20',
        'state': 'sent',
        'device_results': [
          for (final provider in ['apple', 'garmin'])
            {
              'id': provider,
              'scheduled_id': 'appointment',
              'provider': provider,
              'state': provider == 'apple' ? 'associated' : 'review',
              'name': 'Carrera sintética',
              'started_at': '2026-10-20T08:00:00Z',
              'timer_seconds': 120,
              'distance_meters': 400,
            },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeviceTrainingProgressTile(progress: progress)),
        ),
      );
      expect(find.text('Resultado recibido de Apple Watch'), findsOneWidget);
      expect(find.text('Garmin · Pendiente de revisión'), findsOneWidget);
      expect(find.text('2:00 · 0.40 km'), findsNWidgets(2));
      expect(find.text('Resultados incorporados a la sesión'), findsNothing);
      expect(find.text('Sesión completada'), findsNothing);
    },
  );
  testWidgets(
    'Garmin sin pauta muestra sus datos sin anunciar una sesión completada',
    (tester) async {
      final garmin = DeviceActivitySummary.fromJson({
        'id': 'garmin',
        'scheduled_id': null,
        'provider': 'garmin',
        'state': 'unassigned',
        'name': 'Carrera sintética',
        'started_at': '2026-10-20T08:00:00Z',
        'timer_seconds': 120.125,
        'distance_meters': 420.25,
        'interval_count': 3,
        'average_heart_rate': 125,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceActivitySummaryCard(result: garmin, showName: true),
          ),
        ),
      );
      expect(
        find.textContaining('Garmin · Pendiente de asociar'),
        findsOneWidget,
      );
      expect(find.textContaining('2:00 · 0.42 km'), findsOneWidget);
      expect(find.textContaining('FC media'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('FC media: 125 ppm'), findsOneWidget);
      expect(find.text('3 vueltas disponibles'), findsOneWidget);
      expect(find.textContaining('Todavía no está asociada'), findsOneWidget);
    },
  );
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
                deviceResults: [result],
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
