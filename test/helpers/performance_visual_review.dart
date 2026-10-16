import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captura optativa de widgets reales, sin cuentas ni datos personales.
const capturePerformanceReview = bool.fromEnvironment(
  'CAPTURE_PERFORMANCE_REVIEW',
);
Future<void> loadReviewFont({bool always = false}) async {
  if (!capturePerformanceReview && !always) return;
  final fontDirectory =
      Platform.environment['PERFORMANCE_REVIEW_FONT_DIR'] ??
      (always
          ? '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts'
          : null);
  final bytes = await File(
    fontDirectory == null
        ? 'C:/Windows/Fonts/arial.ttf'
        : '$fontDirectory/Roboto-Regular.ttf',
  ).readAsBytes();
  await (FontLoader(
    'Roboto',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  final iconFile = File(
    fontDirectory == null
        ? 'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        : '$fontDirectory/MaterialIcons-Regular.otf',
  );
  if (await iconFile.exists()) {
    final icons = await iconFile.readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  }
}

Future<void> capturePerformanceWidget(WidgetTester tester, String name) async {
  if (!capturePerformanceReview) return;
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('review-boundary')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/performance_v2_review')
      ..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}
