import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:workout_editor_ui/profile_photo_picker.dart';

void main() {
  testWidgets(
    'encuadre a 320 con texto 2x mantiene tamaño y acciones accesibles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = Uint8List.fromList(
        image.encodePng(image.Image(width: 100, height: 50)),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ProfilePhotoCropDialog(
              bytes: bytes,
              width: 100,
              height: 50,
              side: 240,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(InteractiveViewer)),
        const Size(240, 240),
      );
      await tester.ensureVisible(find.text('Usar foto'));
      await tester.pumpAndSettle();
      expect(find.text('Usar foto').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'encuadre permite desplazar la imagen y confirmar la zona elegida',
    (tester) async {
      ({double x, double y, double size})? crop;
      final bytes = Uint8List.fromList(
        image.encodePng(image.Image(width: 100, height: 50)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  crop = await showDialog<({double x, double y, double size})>(
                    context: context,
                    builder: (_) => ProfilePhotoCropDialog(
                      bytes: bytes,
                      width: 100,
                      height: 50,
                      side: 200,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(InteractiveViewer), const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar foto'));
      await tester.pumpAndSettle();
      expect(crop, isNotNull);
      expect(crop!.x, closeTo(50, .1));
      expect(crop!.y, closeTo(0, .1));
      expect(crop!.size, closeTo(50, .1));
    },
  );
  test('encuadre elegido produce JPEG cuadrado ligero sin EXIF', () {
    final original = image.Image(width: 100, height: 50);
    image.fill(original, color: image.ColorRgb8(255, 0, 0));
    image.fillRect(
      original,
      x1: 50,
      y1: 0,
      x2: 99,
      y2: 49,
      color: image.ColorRgb8(0, 0, 255),
    );
    final result = encodeProfilePhotoCrop(
      Uint8List.fromList(image.encodePng(original)),
      x: 50,
      y: 0,
      size: 50,
    );
    final decoded = image.decodeJpg(result)!;
    expect(decoded.width, 512);
    expect(decoded.height, 512);
    expect(result.length, lessThanOrEqualTo(200 * 1024));
    expect(decoded.getPixel(256, 256).b, greaterThan(220));
    expect(decoded.getPixel(256, 256).r, lessThan(20));
    expect(decoded.exif.isEmpty, isTrue);
  });
  test('rechaza encuadres inválidos e imágenes ilegibles', () {
    expect(
      () => encodeProfilePhotoCrop(Uint8List(0), x: 0, y: 0, size: 10),
      throwsFormatException,
    );
    expect(
      () => encodeProfilePhotoCrop(Uint8List(0), x: double.nan, y: 0, size: 10),
      throwsFormatException,
    );
  });
}
