// Captura cada fotograma de las animaciones reales del motor Flutter.
// Los intervalos quietos conservan su duración sin generar PNG duplicados.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class DemoRecorder {
  DemoRecorder(this.tester, this.output);
  final WidgetTester tester;
  final String output;
  final boundary = GlobalKey();
  final entries = <String>[];
  int sequence = 0;
  String? last;

  Future<void> mount(Widget app, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final fontDir =
          Platform.environment['FLUTTER_FONT_DIR'] ??
          'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
      for (final (family, filename) in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        final bytes = await File('$fontDir/$filename').readAsBytes();
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      await Directory(output).create(recursive: true);
    });
    await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
    await tester.pumpAndSettle();
    // La marca está en assets locales: precargar antes de filmar.
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(
          'assets/branding/entrenaop_wordmark_on_dark.png',
          package: 'entrena_ui',
        ),
        boundary.currentContext!,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> frame(double duration) async {
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '$output/frame-${(sequence++).toString().padLeft(5, '0')}.png',
      );
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      last = file.absolute.path.replaceAll('\\', '/');
      entries.add("file '$last'\nduration $duration");
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> hold(double seconds) => frame(seconds);
  Future<void> animate([double seconds = 0.5]) async {
    for (var i = 0; i < (seconds * 20).round(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await frame(0.05);
    }
  }

  Future<void> tap(Finder finder) async {
    expect(finder.hitTestable(), findsWidgets);
    await tester.tap(finder.hitTestable().first);
    await animate(0.6);
  }

  Future<void> scroll(Finder scrollable, double distance) async {
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(0, -distance / 20));
      await tester.pump(const Duration(milliseconds: 50));
      await frame(0.05);
    }
    await gesture.up();
    await animate(0.3);
  }

  Future<void> finish() async {
    await tester.runAsync(
      () => File('$output/frames.ffconcat').writeAsString(
        'ffconcat version 1.0\n${entries.join('\n')}\nfile \'$last\'\n',
      ),
    );
  }
}
