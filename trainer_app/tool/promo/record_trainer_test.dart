import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools/promo/frame_recorder.dart';
import 'trainer_demo.dart';

void main() {
  testWidgets(
    'graba alumnos ficticios, ficha, agenda y conversación de Trainer',
    (tester) async {
      final key = GlobalKey<TrainerDemoState>();
      final recorder = DemoRecorder(
        tester,
        Platform.environment['PROMO_OUTPUT'] ?? '../build/promo/trainer',
      );
      await recorder.mount(TrainerDemo(key: key), const Size(1280, 800));
      for (final name in [
        'Lucía Vega',
        'Dani Torres',
        'Nora Martín',
        'Marcos Vidal',
      ]) {
        expect(find.text(name), findsWidgets);
      }
      await recorder.hold(3);
      await recorder.tap(find.text('Lucía Vega').first);
      await recorder.hold(3);
      key.currentState!.router.go('/agenda');
      await recorder.animate(0.7);
      await recorder.hold(4);
      key.currentState!.router.go('/messages');
      await recorder.animate(0.7);
      await recorder.hold(3);
      await recorder.finish();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
