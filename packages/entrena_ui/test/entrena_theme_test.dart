import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void main() {
  test('acción principal y texto auxiliar mantienen contraste legible', () {
    final scheme = EntrenaTheme.dark.colorScheme;
    expect(
      _contrast(scheme.primary, scheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(EntrenaVisuals.dark.surface, EntrenaVisuals.dark.textMuted),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(EntrenaVisuals.dark.surfaceHigh, scheme.onSurface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'campos, etiquetas y menús comparten superficies sin perder controles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(labelText: 'Nombre'),
                ),
                ChoiceChip(
                  label: const Text('Borrador'),
                  selected: true,
                  onSelected: (_) {},
                ),
                PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
