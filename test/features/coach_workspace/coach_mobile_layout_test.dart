import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coach_mobile_fixture.dart';
import '../../support/coach_workspace_fixture.dart';

void main() {
  const capture = String.fromEnvironment('COACH_CAPTURE_DIR');
  final screens = {
    'resumen': '/coach',
    'agenda': '/coach/agenda',
    'alumnos': '/coach/clients',
    'mensajes': '/coach/messages',
    'ficha': '/coach/clients/isabel',
    'resultado': '/coach/assignment/session',
    'sesion-pendiente': '/coach/assignment/carrera',
    'calendario': '/coach/calendar/isabel',
    'tecnica': '/coach/technique/session',
    'conversacion': '/coach/messages/relation',
    'revisiones': '/coach/reviews',
    'videos': '/coach/videos',
  };

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('consulta poblada iPhone $width texto $scale', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (capture.isNotEmpty) {
          await tester.runAsync(() async {
            final fontBytes = ByteData.sublistView(
              await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
            );
            for (final family in [
              'Roboto',
              'CupertinoSystemText',
              'CupertinoSystemDisplay',
              '.AppleSystemUIFont',
              'Segoe UI',
            ]) {
              final font = FontLoader(family)..addFont(Future.value(fontBytes));
              await font.load();
            }
            final icons = FontLoader('MaterialIcons')
              ..addFont(
                File(
                  'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytes().then(ByteData.sublistView),
              );
            await icons.load();
          });
        }
        final router = createRouter(
          CoachMobileFixture(),
          FakeSecurity(),
          initial: '/coach',
        );
        addTearDown(router.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in screens.entries) {
          router.go(entry.value);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key}: $width / $scale',
          );
          expect(router.state.uri.path, entry.value);
          expect(
            find.byKey(const ValueKey('app-workspace-switcher')).hitTestable(),
            findsOneWidget,
            reason: 'Selector de espacio accesible en ${entry.key}',
          );
          if (entry.key == 'resultado') {
            await tester.scrollUntilVisible(
              find.byType(Switch),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            expect(
              find.byType(Switch).hitTestable(),
              findsOneWidget,
              reason:
                  'Control ${tester.getRect(find.byType(Switch))}; lista ${tester.getRect(find.byType(Scrollable).last)}',
            );
            await tester.tap(find.byType(Switch));
            await tester.pumpAndSettle();
            expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
          }
          if (capture.isNotEmpty &&
              width == 390 &&
              (scale == 1 || scale == 2)) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$capture/${entry.key}-${scale.toInt()}x.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        Future<void> chooseSpace(bool professional) async {
          if (find.byType(PopupMenuButton<bool>).evaluate().isNotEmpty) {
            await tester.tap(
              find.byKey(const ValueKey('app-workspace-switcher')),
            );
            await tester.pumpAndSettle();
            final item = find.byWidgetPredicate(
              (widget) =>
                  widget is PopupMenuItem<bool> && widget.value == professional,
            );
            await tester.tap(item);
          } else {
            await tester.tap(
              find.text(professional ? 'Entrenador' : 'Mi entrenamiento'),
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await chooseSpace(false);
        expect(router.state.uri.path, '/home');
        await chooseSpace(true);
        expect(router.state.uri.path, '/coach/videos');
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
