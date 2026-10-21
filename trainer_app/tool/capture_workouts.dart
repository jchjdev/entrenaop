// Capturas de los widgets reales con recetas y alumnos ficticios, sin red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_result.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../test/trainer_workout_flow_test.dart';

void main() {
  var fontsLoaded = false;
  for (final (size, width, scale) in [
    ('desktop', 1200.0, 1.0),
    ('mobile-text2x', 320.0, 2.0),
  ]) {
    for (final screen in ['library', 'client', 'result', 'assign']) {
      testWidgets('$screen $size', (tester) async {
        if (!fontsLoaded) {
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
          fontsLoaded = true;
        }
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = WorkoutFixture();
        final access = FakeTrainerRepository()
          ..active = [trainerRelation('Lucía Fernández')];
        final widget = switch (screen) {
          'library' => TrainerWorkoutLibraryPage(
            repository: repo,
            accessRepository: access,
          ),
          'client' => TrainerClientWorkoutsPage(
            repository: repo,
            accessRepository: access,
            clientId: access.active.single.personId,
          ),
          'assign' => Scaffold(
            body: TrainerAssignmentDialog(
              repository: repo,
              relationId: access.active.single.id,
            ),
          ),
          _ => Scaffold(
            appBar: AppBar(title: const Text('Resultado del alumno')),
            body: TrainerWorkoutResultContent(result: resultFixture),
          ),
        };
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
            home: widget,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            '../docs/visual-audit/trainer-private-workouts-2026-10-21/$screen-$size.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
