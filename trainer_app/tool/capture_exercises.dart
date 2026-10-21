// Capturas de widgets reales con biblioteca ficticia, sin cuentas ni alumnos.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../test/trainer_exercise_flow_test.dart' as fixtures;

void main() {
  var loaded = false;
  for (final (size, width, scale) in [
    ('desktop', 1200.0, 1.0),
    ('mobile', 390.0, 1.0),
    ('mobile-text2x', 390.0, 2.0),
  ]) {
    for (final editor in [false, true]) {
      testWidgets('$size editor=$editor', (tester) async {
        if (!loaded) {
          await tester.runAsync(() async {
            for (final (family, path) in [
              ('Roboto', 'C:/Windows/Fonts/arial.ttf'),
              (
                'MaterialIcons',
                'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ),
            ]) {
              final bytes = await File(path).readAsBytes();
              await (FontLoader(
                family,
              )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
            }
          });
          loaded = true;
        }
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = fixtures.ExerciseFixture()
          ..rows = [
            fixtures.entry('Dominada con pausa'),
            fixtures.entry('Flexión con apoyo específico'),
          ];
        await tester.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: const ValueKey('capture'),
                child: child!,
              ),
            ),
            home: TrainerShell(
              location: '/exercises',
              child: TrainerExercisePage(
                repository: repo,
                access: FakeTrainerRepository(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (editor) {
          await tester.scrollUntilVisible(
            find.text('Crear ejercicio privado'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Crear ejercicio privado'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('trainer-exercise-name')),
            'Dominada con pausa',
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            '../docs/visual-audit/trainer-exercises-2026-10-21/${editor ? 'editor' : 'library'}-$size.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
