import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'professional_workspace_test.dart' show DraftProbe;

void main() {
  testWidgets('redimensiona sin perder el borrador y acota el lienzo', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      const MaterialApp(
        home: ProfessionalWorkspaceScope(
          desktop: true,
          child: Scaffold(
            body: ProfessionalEditorWorkspace(
              library: Text('Biblioteca'),
              inspector: Text('Propiedades'),
              child: DraftProbe(),
            ),
          ),
        ),
      ),
    );
    final library = find.byKey(const ValueKey('professional-library-pane'));
    final inspector = find.byKey(const ValueKey('professional-inspector-pane'));
    final libraryHandle = find.byKey(
      const ValueKey('professional-library-resize'),
    );
    final inspectorHandle = find.byKey(
      const ValueKey('professional-inspector-resize'),
    );
    expect(t.getSize(library).width, 196);
    expect(t.getSize(inspector).width, 400);
    await t.enterText(
      find.byKey(const ValueKey('draft')),
      'Series 4 × 8 sin guardar',
    );
    final state = t.state(find.byType(DraftProbe));
    await t.drag(libraryHandle, const Offset(80, 0));
    await t.pumpAndSettle();
    expect(t.getSize(library).width, 276);
    await t.drag(inspectorHandle, const Offset(-100, 0));
    await t.pumpAndSettle();
    expect(t.getSize(inspector).width, 500);
    await t.binding.setSurfaceSize(const Size(1100, 760));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(DraftProbe)).width, greaterThanOrEqualTo(440));
    expect(t.getSize(inspector).width, greaterThanOrEqualTo(320));
    await t.binding.setSurfaceSize(const Size(320, 760));
    await t.pumpAndSettle();
    expect(libraryHandle, findsNothing);
    expect(t.state(find.byType(DraftProbe)), same(state));
    await t.binding.setSurfaceSize(const Size(1500, 900));
    await t.pumpAndSettle();
    expect(t.getSize(inspector).width, 500);
    expect(t.getSize(library).width, 276);
    expect(
      t.widget<TextField>(find.byKey(const ValueKey('draft'))).controller!.text,
      'Series 4 × 8 sin guardar',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'ratón acumula movimientos, teclado ajusta y doble clic restaura',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        const MaterialApp(
          home: ProfessionalWorkspaceScope(
            desktop: true,
            child: Scaffold(
              body: ProfessionalEditorWorkspace(
                library: Text('Biblioteca'),
                inspector: Text('Propiedades'),
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );
      final handle = find.byKey(
        const ValueKey('professional-inspector-resize'),
      );
      final pane = find.byKey(const ValueKey('professional-inspector-pane'));
      final gesture = await t.startGesture(
        t.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-30, 0));
      await t.pump();
      final before = t.getSize(pane).width;
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-20, 0));
      await t.pump();
      expect(t.getSize(pane).width, before + 40);
      await gesture.up();
      await t.pumpAndSettle();
      final keyboardBefore = t.getSize(pane).width;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(t.getSize(pane).width, keyboardBefore + 24);
      await t.sendKeyEvent(LogicalKeyboardKey.home);
      await t.pumpAndSettle();
      expect(t.getSize(pane).width, 400);
      await t.drag(handle, const Offset(-1000, 0));
      await t.pumpAndSettle();
      expect(t.getSize(pane).width, 560);
      await t.tap(handle);
      await t.pump(const Duration(milliseconds: 80));
      await t.tap(handle);
      await t.pumpAndSettle();
      expect(t.getSize(pane).width, 400);
      expect(t.takeException(), isNull);
    },
  );
}
