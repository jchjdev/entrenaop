import 'package:entrenaop_trainer/trainer_pointer_drag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mountDrag(
  WidgetTester tester,
  List<String> received, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TrainerPointerDrag<String>(
                key: const ValueKey('source'),
                data: 'session',
                feedback: const Material(child: Text('Moviendo sesión')),
                child: Material(
                  child: InkWell(
                    onTap: onTap,
                    child: const SizedBox(
                      width: 140,
                      height: 70,
                      child: Text('Sesión'),
                    ),
                  ),
                ),
              ),
              DragTarget<String>(
                key: const ValueKey('target'),
                onAcceptWithDetails: (details) => received.add(details.data),
                builder: (_, candidates, rejected) => const SizedBox(
                  width: 140,
                  height: 70,
                  child: Text('Día destino'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> moveToTarget(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveBy(const Offset(24, 0));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ratón inicia al mover sin esperar una pulsación larga', (
    tester,
  ) async {
    final received = <String>[];
    await mountDrag(tester, received);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('source'))),
      kind: PointerDeviceKind.mouse,
    );
    await moveToTarget(tester, gesture);
    expect(received, ['session']);
  });

  testWidgets(
    'el dedo desplaza sin mover la sesión y arrastra tras mantener pulsado',
    (tester) async {
      final received = <String>[];
      await mountDrag(tester, received);
      final source = find.byKey(const ValueKey('source'));
      final quick = await tester.startGesture(tester.getCenter(source));
      await moveToTarget(tester, quick);
      expect(received, isEmpty);
      final held = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 600));
      await moveToTarget(tester, held);
      expect(received, ['session']);
    },
  );

  testWidgets('un clic de ratón abre la sesión sin iniciar un arrastre', (
    tester,
  ) async {
    final received = <String>[];
    var clicks = 0;
    await mountDrag(tester, received, onTap: () => clicks++);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('source'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(received, isEmpty);
  });

  testWidgets('cancelar el arrastre no mueve ni bloquea el siguiente intento', (
    tester,
  ) async {
    final received = <String>[];
    await mountDrag(tester, received);
    final source = find.byKey(const ValueKey('source'));
    final cancelled = await tester.startGesture(
      tester.getCenter(source),
      kind: PointerDeviceKind.mouse,
    );
    await cancelled.moveBy(const Offset(28, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(received, isEmpty);
    final again = await tester.startGesture(
      tester.getCenter(source),
      kind: PointerDeviceKind.mouse,
    );
    await moveToTarget(tester, again);
    expect(received, ['session']);
  });
}
