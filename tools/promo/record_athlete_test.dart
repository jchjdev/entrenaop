import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'athlete_demo.dart';
import 'frame_recorder.dart';

void main() {
  testWidgets('graba el recorrido local del deportista sin cuentas ni red', (
    tester,
  ) async {
    final key = GlobalKey<AthleteDemoState>();
    final recorder = DemoRecorder(
      tester,
      Platform.environment['PROMO_OUTPUT'] ?? 'build/promo/athlete',
    );
    await recorder.mount(AthleteDemo(key: key), const Size(390, 844));
    await recorder.hold(2.5);
    // Se utilizan los controles reales y las rutas de la demo, sin dibujar pantallas sustitutas.
    await recorder.tap(find.text('Mi plan').last);
    await recorder.hold(2.5);
    key.currentState!.router.push('/plan/week');
    await recorder.animate(0.7);
    await recorder.hold(3);
    key.currentState!.router.go('/library');
    await recorder.animate(0.6);
    await recorder.hold(2);
    key.currentState!.router.push('/library/exercises');
    await recorder.animate(0.7);
    await recorder.hold(1.5);
    await recorder.tap(find.text('Dominadas'));
    await recorder.hold(2);
    key.currentState!.router.go('/assessment/history');
    await recorder.animate(0.7);
    await recorder.hold(2);
    await recorder.tap(find.text('Comparar marcas'));
    await recorder.scroll(find.byType(Scrollable).hitTestable().first, 240);
    await recorder.hold(2);
    key.currentState!.router.go('/my-trainer');
    await recorder.animate(0.7);
    await recorder.hold(2.5);
    key.currentState!.router.push('/my-trainer/conversations/demo-relation');
    await recorder.animate(0.7);
    await recorder.hold(3);
    await recorder.finish();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
