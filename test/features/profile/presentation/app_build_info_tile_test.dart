import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/config/app_build_info.dart';
import 'package:entrenaop/features/profile/presentation/widgets/app_build_info_tile.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  testWidgets(
    'identidad accesible con texto grande y copia solo datos técnicos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      if (const bool.fromEnvironment('APP_IDENTITY_VISUAL_AUDIT')) {
        await tester.runAsync(() => loadReviewFont(always: true));
      }
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final info = AppBuildInfo(
        version: '1.0.0',
        buildNumber: '2',
        environment: 'Desarrollo (Dev)',
        mode: 'Release',
        revision: 'a' * 40,
        modifiedSources: true,
        builtAt: DateTime.utc(2026, 10, 22),
      );
      final proofKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: proofKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppBuildInfoTile(load: () async => info),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('compilación 2'), findsOneWidget);
      await tester.tap(find.text('Versión de la app'));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('APP_IDENTITY_VISUAL_AUDIT')) {
        await tester.runAsync(() async {
          final boundary =
              proofKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/app-identity-dialog.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Copiar datos de versión'));
      await tester.tap(find.text('Copiar datos de versión'));
      await tester.pumpAndSettle();
      expect(copied, info.diagnosticText);
      expect(copied, contains('cambios locales'));
      expect(copied, isNot(contains('@')));
      expect(
        find.textContaining('No se comprueba automáticamente'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cerrar'));
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Versión de EntrenaOP'), findsNothing);
    },
  );

  testWidgets('un error al leer la versión conserva el perfil', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBuildInfoTile(
            load: () => Future.error(StateError('plugin unavailable')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Versión no disponible'), findsOneWidget);
    expect(find.textContaining('plugin unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
