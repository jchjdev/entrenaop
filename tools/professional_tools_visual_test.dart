// Capturas de los contenedores reales y el creador compartido, sin red ni cuentas.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

// El arnés contrasta los dos consumidores reales sin añadir dependencias entre apps.
// ignore: avoid_relative_lib_imports
import '../admin_app/lib/core/admin_shell.dart';
// ignore: avoid_relative_lib_imports
import '../trainer_app/lib/trainer_shell.dart';

void main() {
  var fontsLoaded = false;
  for (final (name, admin, width, scale) in [
    ('trainer', false, 1440.0, 1.0),
    ('admin', true, 1440.0, 1.0),
    ('trainer-accesible', false, 320.0, 2.0),
  ]) {
    testWidgets('herramientas $name', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          final fontDir =
              Platform.environment['FLUTTER_FONT_DIR'] ??
              'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
          for (final (family, file) in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final bytes = await File('$fontDir/$file').readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
          fontsLoaded = true;
        });
      }
      final path = admin ? '/sessions/new' : '/workouts/new';
      final boundary = GlobalKey();
      final router = GoRouter(
        initialLocation: path,
        routes: [
          ShellRoute(
            builder: (_, state, child) => admin
                ? AdminShell(
                    path: state.uri.path,
                    hasAccess: () async => true,
                    onSignOut: () {},
                    child: child,
                  )
                : TrainerShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(
                path: path,
                builder: (_, _) => WorkoutEditorPage(
                  loadExercises: () async => [],
                  onSave: (_) async => 'fixture',
                  onSaved: (_) {},
                  title: 'Nueva sesión',
                  heading: 'Crea una sesión de carrera',
                  instructions: 'Configura los tramos y consulta los ritmos mientras trabajas.',
                  saveLabel: 'Guardar sesión',
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Herramientas'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<void>, 'Calculadora de ritmos'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/visual-audit/professional-tools-2026-10-24/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
