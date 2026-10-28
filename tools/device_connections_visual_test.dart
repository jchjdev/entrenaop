// Capturas de widgets reales y datos ficticios; sin permisos nativos ni red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_health/device_health.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/device_connections/domain/garmin_connection.dart';
import 'package:entrenaop/features/device_connections/presentation/device_connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var fontsLoaded = false;
  for (final (name, width, scale, available, connected) in [
    ('iphone', 390.0, 1.0, true, true),
    ('web', 390.0, 1.0, false, false),
    ('texto-grande', 360.0, 1.5, true, true),
  ]) {
    testWidgets('captura conexiones $name', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          final directory =
              Platform.environment['FLUTTER_FONT_DIR'] ??
              'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
          for (final (family, file) in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final data = await File('$directory/$file').readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(data)))).load();
          }
          fontsLoaded = true;
        });
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            initialRoute: '/connections',
            routes: {
              '/': (context) => const Scaffold(),
              '/connections': (context) => DeviceConnectionsPage(
                ownerId: 'visual-fixture',
                health: _Health(available),
                garmin: _Garmin(connected),
                onOpenHealth: () async {},
                onOpenGarmin: () async {},
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/visual-audit/device-connections-2026-10-28/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

class _Health extends Fake implements LocalRunningHealth {
  _Health(this.available);
  final bool available;
  @override
  LocalHealthPlatform get platform => available
      ? LocalHealthPlatform.appleHealth
      : LocalHealthPlatform.unsupported;
  @override
  Future<HealthStoreAvailability> availability() async => available
      ? HealthStoreAvailability.available
      : HealthStoreAvailability.unsupported;
}

class _Garmin extends Fake implements GarminConnectionRepository {
  _Garmin(this.connected);
  final bool connected;
  @override
  Future<GarminConnectionSnapshot> load() async => GarminConnectionSnapshot(
    status: connected
        ? GarminConnectionStatus.connected
        : GarminConnectionStatus.disconnected,
    allowed: true,
    generation: 1,
    canRead: connected,
    canSend: connected,
  );
}
