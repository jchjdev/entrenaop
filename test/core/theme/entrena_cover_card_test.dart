import 'dart:typed_data';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'una portada fallida no oculta el contenido ni bloquea la acción',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            body: EntrenaCard(
              coverImage: MemoryImage(Uint8List.fromList([1, 2, 3])),
              focalX: 0.8,
              focalY: 0.3,
              onTap: () => taps++,
              child: const Text('Gestionar preparación'),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final alignment = image.alignment as Alignment;
      expect(alignment.x, closeTo(0.6, 0.00001));
      expect(alignment.y, closeTo(-0.4, 0.00001));
      expect(image.excludeFromSemantics, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Gestionar preparación'), findsOneWidget);
      await tester.tap(find.text('Gestionar preparación'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
