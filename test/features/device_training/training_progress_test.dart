import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/device_training_progress.dart';
import 'package:workout_editor_ui/device_training_progress_tile.dart';

DeviceTrainingProgress progress(
  String state, {
  String? reason,
  bool confirmed = false,
}) => DeviceTrainingProgress.fromJson({
  'id': 'scheduled',
  'name': 'Carrera suave',
  'date': '2026-10-26',
  'state': state,
  'reason': reason,
  'results_confirmed': confirmed,
});

void main() {
  test('un estado nuevo o una fecha corrupta no se convierten en enviado', () {
    expect(() => progress('received_on_watch'), throwsFormatException);
    expect(
      () => DeviceTrainingProgress.fromJson({
        'id': 'schedule',
        'name': 'Carrera',
        'date': 'invalid',
        'state': 'sent',
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'distingue enviada a Garmin de recibida en reloj y permite plegar el detalle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceTrainingProgressTile(progress: progress('sent')),
          ),
        ),
      );
      expect(find.text('Enviada al calendario de Garmin'), findsOneWidget);
      await tester.tap(find.text('Carrera suave'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no acredita recepción'), findsOneWidget);
      await tester.tap(find.text('Carrera suave'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no acredita recepción'), findsNothing);
    },
  );

  testWidgets(
    'no anuncia retirada ni resultado del reloj sin su confirmación',
    (tester) async {
      Widget page(DeviceTrainingProgress p) => MaterialApp(
        home: Scaffold(
          body: DeviceTrainingProgressTile(key: ValueKey(p.phase), progress: p),
        ),
      );
      await tester.pumpWidget(page(progress('cancellation_pending')));
      expect(find.text('Retirada pendiente en Garmin'), findsOneWidget);
      expect(find.text('Retirada confirmada en Garmin'), findsNothing);
      await tester.pumpWidget(page(progress('completed')));
      await tester.pumpAndSettle();
      expect(find.text('Sesión completada'), findsOneWidget);
      expect(find.text('Resultados del reloj incorporados'), findsNothing);
      await tester.pumpWidget(page(progress('completed', confirmed: true)));
      await tester.pumpAndSettle();
      expect(find.text('Resultados del reloj incorporados'), findsOneWidget);
    },
  );

  testWidgets(
    'explica automático apagado y creación incierta en móvil con texto doble',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (state, reason) in [
        ('not_sent', 'auto_disabled'),
        ('review', 'delivery_uncertain'),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DeviceTrainingProgressTile(
                    key: ValueKey(state),
                    progress: progress(state, reason: reason),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carrera suave'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            state == 'not_sent' ? 'debe activar' : 'no se creará otra copia',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
