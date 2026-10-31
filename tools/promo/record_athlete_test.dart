import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'athlete_demo.dart';
import 'frame_recorder.dart';

import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';

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
    key.currentState!.fasReference = await tester.runAsync(
      FasPeriodic2027Reference.load,
    );
    recorder.chapter('home');
    await recorder.hold(2);
    key.currentState!.router.push('/plan/week');
    await recorder.animate(0.7);
    await recorder.hold(2);
    recorder.chapter('session');
    await recorder.still('week');
    await recorder.tap(find.text('Comenzar sesión'));
    await recorder.hold(2);
    await recorder.tap(find.text('Iniciar temporizador'));
    await recorder.realTime(6);
    await recorder.still('session');
    recorder.chapter('fas');
    key.currentState!.router.go('/assessment/fas-calculator');
    await recorder.animate(.8);
    await recorder.tap(find.text('M · mujeres'));
    for (final (id, value) in [
      ('upper_body_push_ups_2_min', '20'),
      ('abdominal_plank', '115'),
      ('run_2000_m', '1020'),
      ('agility_speed_circuit', '14,10'),
    ]) {
      final field = find.byKey(ValueKey('fas-mark-$id'));
      await tester.ensureVisible(field);
      await recorder.animate(.25);
      await tester.enterText(field, value);
      await recorder.animate(.25);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('SUMA ORIENTATIVA'));
    await recorder.animate(.5);
    await recorder.hold(2);
    expect(find.textContaining('4/4'), findsOneWidget);
    await recorder.still('fas');
    recorder.chapter('paces');
    key.currentState!.router.go('/tools/running-pace-calculator');
    await recorder.animate(.8);
    await tester.enterText(
      find.byKey(const ValueKey('running-pace-input')),
      '410',
    );
    await recorder.animate(.5);
    await recorder.hold(2);
    await recorder.scroll(find.byType(Scrollable).hitTestable().first, 280);
    await recorder.hold(2);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('running-total-time')))
          .data,
      '1:40',
    );
    await recorder.still('paces');
    recorder.chapter('marks');
    key.currentState!.router.go('/assessment/history');
    await recorder.animate(0.7);
    await recorder.hold(1);
    await recorder.tap(find.text('Comparar marcas'));
    await recorder.scroll(find.byType(Scrollable).hitTestable().first, 240);
    await recorder.hold(2);
    key.currentState!.router.go('/my-trainer');
    await recorder.animate(0.7);
    await recorder.hold(2);
    await recorder.still('coach');
    await recorder.finish();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
