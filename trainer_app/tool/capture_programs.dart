// Widgets reales y datos ficticios. No conecta con cuentas de alumnos.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../test/trainer_program_flow_test.dart';
import '../test/trainer_workout_flow_test.dart';

void main() {
  var fontsLoaded = false;
  for (final (size, width, scale) in [
    ('desktop', 1200.0, 1.0),
    ('mobile-text2x', 320.0, 2.0),
  ]) {
    for (final screen in ['agenda', 'library', 'program', 'editor', 'assign']) {
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
        final programs = ProgramFixture();
        final page = switch (screen) {
          'agenda' => TrainerAgendaPage(
            repository: AgendaFixture(),
            now: DateTime(2026, 10, 21),
          ),
          'library' => TrainerProgramLibraryPage(
            repository: programs,
            access: FakeTrainerRepository(),
          ),
          'program' => TrainerProgramDetailPage(
            repository: programs,
            workouts: WorkoutFixture(),
            programId: 'program',
          ),
          'editor' => TrainerProgramEditorPage(
            repository: programs,
            workouts: WorkoutFixture(),
            programId: 'program',
          ),
          _ => const SizedBox.shrink(),
        };
        final app = MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('capture'),
              child: child!,
            ),
          ),
          home: screen == 'assign'
              ? Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => TrainerProgramAssignmentDialog(
                          repository: programs,
                          relationId: 'relation',
                        ),
                      ),
                      child: const Text('Abrir pauta'),
                    ),
                  ),
                )
              : TrainerShell(
                  location: screen == 'agenda'
                      ? '/agenda'
                      : screen == 'editor'
                      ? '/programs/program/revise'
                      : '/programs',
                  child: page,
                ),
        );
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        if (screen == 'assign') {
          await tester.tap(find.text('Abrir pauta'));
          await tester.pumpAndSettle();
          await visibleTap(tester, find.text(privateProgram.name));
          await tester.drag(find.byType(ListView).last, const Offset(0, 300));
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
            '../docs/visual-audit/trainer-programs-2026-10-21/$screen-$size.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
