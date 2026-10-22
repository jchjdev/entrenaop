import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/running_step_codec.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/running_workout_estimator.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

WorkoutSetDraft manual(RunningStepKind kind) => WorkoutSetDraft(
  targetType: WorkoutTargetType.manual,
  targetValue: 0,
  restAfterSeconds: 0,
  runningStep: RunningStepMetadata(
    kind: kind,
    completion: RunningStepCompletion.manual,
  ),
);
CreatePersonalWorkoutInput recipe(List<WorkoutSetDraft> sets) =>
    CreatePersonalWorkoutInput(
      name: 'Carrera de referencia',
      description: '',
      blocks: [
        WorkoutBlockDraft(
          name: 'Carrera',
          format: WorkoutBlockFormat.running,
          exercises: [
            WorkoutExerciseDraft(exerciseId: runningExerciseId, sets: sets),
          ],
        ),
      ],
    );
CreatePersonalWorkoutInput reference() => recipe([
  manual(RunningStepKind.warmup),
  ...List.filled(
    5,
    const WorkoutSetDraft(
      targetType: WorkoutTargetType.distance,
      targetValue: 400,
      restAfterSeconds: 0,
      targetPaceMinSecondsPerKm: 240,
      targetPaceMaxSecondsPerKm: 270,
      recoveryType: RunningRecoveryType.passive,
      recoveryDurationSeconds: 90,
      runningStep: RunningStepMetadata(
        kind: RunningStepKind.run,
        completion: RunningStepCompletion.distance,
      ),
    ),
  ),
  manual(RunningStepKind.cooldown),
]);

void main() {
  testWidgets('pasos manuales legibles a 320 px con texto doble', (t) async {
    if (const bool.fromEnvironment('CAPTURE_RUNNING_V2')) {
      await t.runAsync(() async {
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        final icons = await File(
          'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      });
    }
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-running-v2'),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WorkoutEditorPage(
            title: 'Carrera',
            heading: 'Pasos',
            instructions: '',
            saveLabel: 'Guardar',
            fixedRunningMode: true,
            initialEditorState: workoutEditorStateFromInput(reference()).value,
            loadExercises: () async => [],
            onSave: (_) async => 'saved',
            onSaved: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('running-step-header-0')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('running-step-header-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('running-step-header-0')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('En el reloj, termina al pulsar Lap.').first,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_RUNNING_V2')) {
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture-running-v2')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          '../../build/running_v2_review/manual-320-text-2.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await t.scrollUntilVisible(
      find.text('Guardar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  test('receta Lap, cinco series y Lap se recupera sin inventar duración', () {
    final input = reference();
    validateWorkoutDraft(input);
    final raw = workoutEditorStateFromInput(input);
    expect((raw.value['segments'] as List).length, 3);
    expect(raw.value['segments'][1]['countText'], '5');
    final recovered = projectWorkoutEditorSnapshot(raw);
    expect(recovered, input);
    final sets = recovered.blocks.single.exercises.single.sets;
    expect(estimateRunningWorkout(sets).isComplete, isFalse);
    expect(recovered.estimatedDurationMinutes, isNull);
    final json = workoutDraftToJson(recovered);
    final rows = json['blocks'][0]['exercises'][0]['sets'] as List;
    expect(rows.first['target_duration_seconds'], isNull);
    expect(rows.first['target_distance_meters'], isNull);
    expect(rows.first['running_step'], {
      'schema_version': 2,
      'kind': 'warmup',
      'completion': 'manual',
    });
    expect(rows.last['running_step']['kind'], 'cooldown');
    expect(
      rows.sublist(1, 6).every((s) => s['recovery_duration_seconds'] == 90),
      isTrue,
    );
  });
  test(
    'todos los tipos conservan su semántica sin agrupar fases distintas',
    () {
      final input = recipe([
        for (final kind in RunningStepKind.values) manual(kind),
      ]);
      final raw = workoutEditorStateFromInput(input);
      expect(
        (raw.value['segments'] as List).length,
        RunningStepKind.values.length,
      );
      expect(projectWorkoutEditorSnapshot(raw), input);
    },
  );
  test(
    'rechaza manual con medida, metadatos contradictorios y fuerza manual',
    () {
      expect(
        () => validateWorkoutDraft(
          recipe([
            const WorkoutSetDraft(
              targetType: WorkoutTargetType.duration,
              targetValue: 60,
              restAfterSeconds: 0,
              runningStep: RunningStepMetadata(
                kind: RunningStepKind.warmup,
                completion: RunningStepCompletion.manual,
              ),
            ),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => validateWorkoutDraft(
          recipe([
            const WorkoutSetDraft(
              targetType: WorkoutTargetType.manual,
              targetValue: 0,
              restAfterSeconds: 0,
            ),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => validateWorkoutDraft(
          CreatePersonalWorkoutInput(
            name: 'Fuerza manual',
            blocks: [
              WorkoutBlockDraft(
                name: 'Principal',
                exercises: [
                  WorkoutExerciseDraft(
                    exerciseId: 'strength',
                    sets: [manual(RunningStepKind.run)],
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RunningStepCodec.decode({
          'schema_version': 3,
          'kind': 'warmup',
          'completion': 'manual',
        }),
        throwsFormatException,
      );
    },
  );
  test('rechaza descanso por distancia o con objetivo de ritmo', () {
    for (final type in [
      WorkoutTargetType.distance,
      WorkoutTargetType.duration,
    ]) {
      expect(
        () => validateWorkoutDraft(
          recipe([
            WorkoutSetDraft(
              targetType: type,
              targetValue: 60,
              restAfterSeconds: 0,
              targetPaceMinSecondsPerKm: 240,
              targetPaceMaxSecondsPerKm: 270,
              runningStep: RunningStepMetadata(
                kind: RunningStepKind.rest,
                completion: type == WorkoutTargetType.distance
                    ? RunningStepCompletion.distance
                    : RunningStepCompletion.time,
              ),
            ),
          ]),
        ),
        throwsFormatException,
      );
    }
  });
  testWidgets('el formulario común recupera y guarda la receta completa', (
    t,
  ) async {
    CreatePersonalWorkoutInput? saved;
    await t.pumpWidget(
      MaterialApp(
        home: WorkoutEditorPage(
          title: 'Carrera',
          heading: 'Pasos',
          instructions: '',
          saveLabel: 'Guardar',
          fixedRunningMode: true,
          initialEditorState: workoutEditorStateFromInput(reference()).value,
          loadExercises: () async => [],
          onSave: (input) async {
            saved = input;
            return 'saved';
          },
          onSaved: (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Guardar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(
      find.text('Duración abierta: hay pasos hasta avance manual.'),
      findsOneWidget,
    );
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(saved, reference());
    expect(t.takeException(), isNull);
  });
}
