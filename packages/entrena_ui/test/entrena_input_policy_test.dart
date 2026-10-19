import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('perder el foco por código retira el teclado nativo', (t) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => EntrenaInputPolicy(child: child!),
        home: Scaffold(body: TextField(focusNode: focus)),
      ),
    );
    await t.enterText(find.byType(TextField), 'Conservado');
    await t.pump();
    expect(t.testTextInput.isVisible, isTrue);
    focus.unfocus();
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isFalse);
    expect(find.text('Conservado'), findsOneWidget);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'tocar fuera cierra el teclado sin consumir acciones en $platform',
      (t) async {
        var presses = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (_, child) => EntrenaInputPolicy(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  const TextField(key: ValueKey('first')),
                  TextFormField(key: const ValueKey('second')),
                  FilledButton(
                    onPressed: () => presses++,
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
        );
        await t.enterText(find.byKey(const ValueKey('first')), 'Primero');
        await t.pump();
        expect(t.testTextInput.isVisible, isTrue);
        await t.tap(find.byKey(const ValueKey('second')));
        await t.pump();
        expect(t.testTextInput.isVisible, isTrue);
        await t.enterText(find.byKey(const ValueKey('second')), 'Segundo');
        await t.tap(find.text('Guardar'));
        await t.pumpAndSettle();
        expect(presses, 1);
        expect(t.testTextInput.isVisible, isFalse);
        expect(find.text('Primero'), findsOneWidget);
        expect(find.text('Segundo'), findsOneWidget);
      },
    );
  }

  testWidgets('accesorios del campo conservan teclado y selección', (t) async {
    var visible = false;
    await t.pumpWidget(
      MaterialApp(
        builder: (_, child) => EntrenaInputPolicy(child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, update) => TextField(
              obscureText: !visible,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: 'Ver contraseña',
                  onPressed: () => update(() => visible = !visible),
                  icon: const Icon(Icons.visibility),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'Conservada');
    await t.pump();
    await t.tap(find.byTooltip('Ver contraseña'));
    await t.pump();
    expect(visible, isTrue);
    expect(t.testTextInput.isVisible, isTrue);
    expect(
      t.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Conservada',
    );
  });

  for (final sheet in [false, true]) {
    testWidgets('cubre overlays y regreso al cerrar, panel $sheet', (t) async {
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => EntrenaInputPolicy(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  final content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TextField(),
                      const SizedBox(
                        height: 30,
                        child: Center(child: Text('Fuera')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  );
                  if (sheet) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => content,
                    );
                  } else {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(content: content),
                    );
                  }
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Retenido');
      await t.pump();
      await t.tap(find.text('Fuera'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(t.testTextInput.isVisible, isTrue);
      await t.tap(find.text('Cerrar'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(find.text('Abrir'), findsOneWidget);
    });
  }

  testWidgets(
    'desplazar la página cierra; desplazar texto multilínea lo conserva',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          builder: (_, child) => EntrenaInputPolicy(child: child!),
          home: Scaffold(
            body: ListView(
              children: [
                const TextField(maxLines: 3),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      await t.enterText(
        find.byType(TextField),
        List.filled(20, 'Una línea').join('\n'),
      );
      await t.pump();
      await t.drag(find.byType(TextField), const Offset(0, 80));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isTrue);
      await t.dragFrom(const Offset(350, 400), const Offset(0, -100));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
    },
  );
}
