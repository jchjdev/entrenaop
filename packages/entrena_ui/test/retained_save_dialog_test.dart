import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(String) save,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (_) => RetainedSaveDialog<String>(
                save: save,
                errorMessage: 'No se pudo guardar. El formulario sigue aquí.',
                builder: (context, submit, saving, error, dirty) => _Form(
                  submit: submit,
                  saving: saving,
                  error: error,
                  dirty: dirty,
                ),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

class _Form extends StatefulWidget {
  const _Form({
    required this.submit,
    required this.saving,
    required this.error,
    required this.dirty,
  });
  final ValueChanged<String> submit;
  final ValueChanged<bool> dirty;
  final bool saving;
  final String? error;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          onChanged: (value) => widget.dirty(value.isNotEmpty),
        ),
        if (widget.error != null) Text(widget.error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => widget.submit(_name.text),
        child: const Text('Guardar'),
      ),
    ],
  );
}

void main() {
  testWidgets(
    'cancelar la revisión conserva campos sin error y permite guardar después',
    (tester) async {
      var attempts = 0;
      await _open(tester, (value) async {
        if (++attempts == 1) throw const RetainedSaveCancelled();
        expect(value, 'Baremo revisado');
      });
      await tester.enterText(find.byType(TextField), 'Baremo revisado');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('No se pudo'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Baremo revisado',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(attempts, 2);
    },
  );

  testWidgets('un fallo conserva los campos y un reintento correcto cierra', (
    tester,
  ) async {
    var calls = 0;
    await _open(tester, (value) async {
      expect(value, 'Mi ejercicio');
      if (++calls == 1) throw StateError('offline');
    });
    await tester.enterText(find.byType(TextField), 'Mi ejercicio');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('formulario sigue aquí'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Mi ejercicio',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, 2);
  });

  testWidgets('guardar bloquea atrás y doble envío hasta terminar', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await _open(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(find.byType(TextField), 'Serie');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
    await Navigator.of(tester.element(find.byType(TextField))).maybePop();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('¿Salir sin guardar?'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'cancelar el descarte mantiene el formulario sin llamar al guardado',
    (tester) async {
      var calls = 0;
      await _open(tester, (_) async {
        calls++;
      });
      await tester.enterText(find.byType(TextField), 'Borrador');
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Borrador',
      );
      expect(calls, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
