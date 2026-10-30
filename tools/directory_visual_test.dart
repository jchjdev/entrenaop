import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/directory/presentation.dart';

import '../test/features/trainers/trainer_directory_test.dart' as fixture;

void main() {
  setUpAll(() async {
    final fontRoot =
        Platform.environment['DIRECTORY_REVIEW_FONT_DIR'] ??
        'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      final file = File('$fontRoot/${font.$2}');
      if (!file.existsSync())
        throw StateError(
          'Configura DIRECTORY_REVIEW_FONT_DIR con las fuentes del SDK.',
        );
      final loader = FontLoader(font.$1)
        ..addFont(file.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('directorio y denuncia a $width con texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final repository = fixture.FakeDirectory();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
              child: child!,
            ),
            home: TrainerDirectoryPage(
              repository: repository,
              loadPhoto: (_) async =>
                  throw const FormatException('Sin fotografía de muestra'),
              profileId: 'one',
              onOpen: (_) {},
              onContact: (_) async => true,
              publicBase: Uri.parse('https://example.test/directory'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('build/directory-review').create(recursive: true);
        await File('build/directory-review/profile-${width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.scrollUntilVisible(
        find.text('Denunciar perfil'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar perfil'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
