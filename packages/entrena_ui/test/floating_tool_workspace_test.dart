import 'dart:ui' show PointerDeviceKind;

import 'package:entrena_ui/floating_tool_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    VoidCallback? onToolBuild,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: FloatingToolWorkspace(
          title: 'Ritmos',
          toolBuilder: (_) {
            onToolBuild?.call();
            return const TextField(key: ValueKey('tool-input'));
          },
          child: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: FloatingToolWorkspace.openerOf(context),
                        child: const Text('Abrir ritmos'),
                      ),
                      const TextField(key: ValueKey('editor-input')),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              const AlertDialog(title: Text('Guardar sesión')),
                        ),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir ritmos'));
    await tester.pumpAndSettle();
  }

  testWidgets('es no modal, minimiza conservando campos y cerrar reinicia', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byKey(const ValueKey('tool-input')), '4:15');
    await tester.enterText(
      find.byKey(const ValueKey('editor-input')),
      'Sesión pendiente',
    );
    expect(find.text('Sesión pendiente'), findsOneWidget);
    await tester.tap(find.byTooltip('Minimizar calculadora'));
    await tester.pump();
    expect(find.byKey(const ValueKey('tool-input')), findsNothing);
    await tester.tap(find.byTooltip('Restaurar calculadora'));
    await tester.pump();
    expect(find.text('4:15'), findsOneWidget);
    expect(find.text('Sesión pendiente'), findsOneWidget);
    await tester.tap(find.text('Abrir ritmos'));
    await tester.pump();
    expect(find.byKey(const ValueKey('floating-tool-window')), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar calculadora'));
    await tester.pump();
    await tester.tap(find.text('Abrir ritmos'));
    await tester.pump();
    expect(find.text('4:15'), findsNothing);
    expect(find.text('Sesión pendiente'), findsOneWidget);
  });

  testWidgets(
    'se mueve con ratón y teclado y permanece dentro al redimensionar',
    (tester) async {
      await mount(tester);
      final window = find.byKey(const ValueKey('floating-tool-window'));
      final handle = find.byKey(const ValueKey('floating-tool-handle'));
      final original = tester.getRect(window);
      await tester.drag(handle, const Offset(-250, 100));
      await tester.pump();
      final moved = tester.getRect(window);
      expect(moved.left, lessThan(original.left));
      expect(moved.top, greaterThan(original.top));
      await tester.tap(handle);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(tester.getRect(window).left, moved.left - 20);
      await tester.drag(handle, const Offset(3000, -3000));
      await tester.pump();
      expect(tester.getRect(window).top, greaterThanOrEqualTo(8));
      expect(tester.getRect(window).right, lessThanOrEqualTo(1392));
      await tester.binding.setSurfaceSize(const Size(320, 600));
      await tester.pumpAndSettle();
      final narrow = tester.getRect(window);
      expect(narrow.left, greaterThanOrEqualTo(8));
      expect(narrow.right, lessThanOrEqualTo(312));
      expect(narrow.bottom, lessThanOrEqualTo(592));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un diálogo del editor conserva su prioridad sobre la herramienta',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar sesión'), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
      await tester.tapAt(const Offset(20, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-input')), findsOneWidget);
    },
  );

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('conserva movimientos entre fotogramas con ${kind.name}', (
      tester,
    ) async {
      var builds = 0;
      await mount(tester, onToolBuild: () => builds++);
      final window = find.byKey(const ValueKey('floating-tool-window'));
      final handle = find.byKey(const ValueKey('floating-tool-handle'));
      final before = tester.getRect(window);
      final beforeBuilds = builds;
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: kind,
      );
      // Tres eventos antes de repintar deben conservar todo el recorrido.
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(tester.getRect(window).left, closeTo(before.left - 120, 0.01));
      expect(builds, beforeBuilds);
      await gesture.up();
      expect(tester.takeException(), isNull);
    });
  }
}
