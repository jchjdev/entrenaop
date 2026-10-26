import 'package:entrenaop/features/profile/presentation/edit_profile_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('conserva borrador tras error y permite confirmar el reintento', (
    t,
  ) async {
    var attempts = 0;
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await editProfileName(
                context,
                current: 'Antes',
                save: (name) async {
                  attempts++;
                  if (attempts == 1) throw StateError('Sin conexión');
                  return name.trim();
                },
              );
            },
            child: const Text('Editar'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Editar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Javier Charlez');
    await t.tap(find.text('Guardar nombre'));
    await t.pumpAndSettle();
    expect(find.textContaining('No se pudo confirmar'), findsOneWidget);
    expect(find.text('Javier Charlez'), findsOneWidget);
    expect(result, isNull);
    await t.tap(find.text('Guardar nombre'));
    await t.pumpAndSettle();
    expect(attempts, 2);
    expect(result, 'Javier Charlez');
  });

  testWidgets('no envía nombres vacíos y cancelar no guarda', (t) async {
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => editProfileName(
              context,
              current: 'Antes',
              save: (name) async {
                calls++;
                return name;
              },
            ),
            child: const Text('Editar'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Editar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.text('Guardar nombre'));
    await t.pumpAndSettle();
    expect(find.textContaining('Escribe un nombre'), findsOneWidget);
    expect(calls, 0);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(find.text('Cambiar nombre'), findsNothing);
    expect(calls, 0);
  });
}
