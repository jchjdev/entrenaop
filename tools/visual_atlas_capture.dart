// Instrumentación de capturas: se importa solo desde copias de fixtures en build/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String atlasSource = '';
String _description = '';
int _sequence = 0;
bool _fontsLoaded = false;
const _boundaryKey = ValueKey('atlas-full-frame');

void atlasTestWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  dynamic timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  int? retry,
  dynamic experimentalLeakTesting,
}) {
  testWidgets(
    description,
    (tester) async {
      _description = description;
      _sequence = 0;
      WidgetsApp.debugAllowBannerOverride = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async =>
                Directory('build/visual-atlas-20261007/cache').absolute.path,
          );
      Directory('build/visual-atlas-20261007/cache')
          .createSync(recursive: true);
      await callback(tester);
      // El render asíncrono permite arrancar la limpieza de caché de imágenes.
      await tester.pump(const Duration(seconds: 11));
      await _capture(tester, 'final');
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    retry: retry,
    experimentalLeakTesting: experimentalLeakTesting,
  );
}

Future<void> _fonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  await tester.runAsync(() async {
    for (final item in <(String, String)>[
      ('Roboto', 'C:/Windows/Fonts/arial.ttf'),
      (
        'MaterialIcons',
        'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final file = File(item.$2);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      await (FontLoader(
        item.$1,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  _fontsLoaded = true;
}

Future<void> atlasPumpWidget(
  WidgetTester tester,
  Widget widget, {
  Duration? duration,
  EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  bool wrapWithView = true,
}) async {
  await _fonts(tester);
  await tester.pumpWidget(
    RepaintBoundary(key: _boundaryKey, child: widget),
    duration: duration,
    phase: phase,
    wrapWithView: wrapWithView,
  );
  await _capture(tester, 'montada');
}

Future<int> atlasSettle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 100),
  EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  Duration timeout = const Duration(minutes: 10),
]) async {
  final frames = await tester.pumpAndSettle(duration, phase, timeout);
  await _capture(tester, 'estable');
  return frames;
}

Future<void> _capture(WidgetTester tester, String stage) async {
  final root = find.byKey(_boundaryKey);
  if (root.evaluate().isEmpty) return;
  final names = find
      .byWidgetPredicate((widget) {
        final name = widget.runtimeType.toString();
        return name.endsWith('Page') ||
            name.endsWith('Dialog') ||
            name.endsWith('Lab') ||
            name == 'ProgramCoverEditor' ||
            name == 'ProgramPhaseSection' ||
            name == 'RunningWeekPreviewSection';
      })
      .evaluate()
      .map((e) => e.widget.runtimeType.toString())
      .toSet()
      .toList();
  if (names.isEmpty) return;
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) {
        final text = e.widget as Text;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      })
      .where((s) => s.trim().isNotEmpty)
      .take(150)
      .toList();
  final boundary = tester.renderObject<RenderRepaintBoundary>(root);
  if (boundary.debugNeedsPaint || boundary.size.isEmpty) return;
  final sequence = _sequence++;
  final stem = atlasSource.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final id = '${stem}_${_description.hashCode.toUnsigned(32)}_$sequence';
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = Directory('build/visual-atlas-20261007/raw')
      ..createSync(recursive: true);
    await File('${out.path}/$id.png').writeAsBytes(bytes!.buffer.asUint8List());
    await File('${out.path}/$id.json').writeAsString(
      jsonEncode({
        'source': atlasSource,
        'description': _description,
        'stage': stage,
        'sequence': sequence,
        'widgets': names,
        'texts': texts,
        'width': image.width,
        'height': image.height,
        'commit': const String.fromEnvironment('ATLAS_COMMIT'),
        'provenance': 'Widgets reales; datos ficticios de tests; tema EntrenaTheme.dark; Arial sustituye el fallback Ahem de tests.',
      }),
    );
    image.dispose();
  });
}
