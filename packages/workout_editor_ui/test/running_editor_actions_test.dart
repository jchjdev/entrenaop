import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_editor_actions.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';

import '../../../test/helpers/performance_visual_review.dart';

WorkoutSetDraft _lap(RunningStepKind kind) => WorkoutSetDraft(
  targetType: WorkoutTargetType.manual,
  targetValue: 0,
  restAfterSeconds: 0,
  runningStep: RunningStepMetadata(
    kind: kind,
    completion: RunningStepCompletion.manual,
  ),
);
const _fast = WorkoutSetDraft(
  targetType: WorkoutTargetType.duration,
  targetValue: 240,
  restAfterSeconds: 0,
  targetPaceMinSecondsPerKm: 250,
  targetPaceMaxSecondsPerKm: 265,
  runningStep: RunningStepMetadata(
    kind: RunningStepKind.run,
    completion: RunningStepCompletion.time,
  ),
);
const _soft = WorkoutSetDraft(
  targetType: WorkoutTargetType.duration,
  targetValue: 180,
  restAfterSeconds: 0,
  targetPaceMinSecondsPerKm: 300,
  targetPaceMaxSecondsPerKm: 320,
  runningStep: RunningStepMetadata(
    kind: RunningStepKind.recovery,
    completion: RunningStepCompletion.time,
  ),
);
const _attached = WorkoutSetDraft(
  targetType: WorkoutTargetType.duration,
  targetValue: 240,
  restAfterSeconds: 0,
  targetPaceMinSecondsPerKm: 250,
  targetPaceMaxSecondsPerKm: 265,
  recoveryType: RunningRecoveryType.jogging,
  recoveryDurationSeconds: 180,
  runningStep: RunningStepMetadata(
    kind: RunningStepKind.run,
    completion: RunningStepCompletion.time,
  ),
);
CreatePersonalWorkoutInput _recipe(List<WorkoutSetDraft> sets) =>
    CreatePersonalWorkoutInput(
      name: 'Fartlek de prueba',
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
WorkoutEditorSnapshot _state({bool attached = false}) =>
    workoutEditorStateFromInput(
      _recipe([
        _lap(RunningStepKind.warmup),
        if (attached) _attached else ...[_fast, _soft],
        _lap(RunningStepKind.cooldown),
      ]),
    );
List<WorkoutSetDraft> _sets(WorkoutEditorSnapshot snapshot) =>
    projectWorkoutEditorSnapshot(snapshot).blocks.single.exercises.single.sets;

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('grupo y omisión legibles a $width con texto doble', (t) async {
      await t.runAsync(loadReviewFont);
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: WorkoutEditorPage(
              title: 'Carrera',
              heading: 'Fartlek',
              instructions: '',
              saveLabel: 'Guardar prueba',
              fixedRunningMode: true,
              initialEditorState: _state().value,
              loadExercises: () async => [],
              onSave: (_) async => 'saved',
              onSaved: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Repetir grupo'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Repetir grupo'));
      await t.pumpAndSettle();
      await capturePerformanceWidget(t, 'fartlek-group-$width-text-2-top');
      await t.ensureVisible(find.text('Omitir última recuperación'));
      await t.pumpAndSettle();
      await t.tap(find.text('Omitir última recuperación'));
      await t.pumpAndSettle();
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await capturePerformanceWidget(t, 'fartlek-group-$width-text-2-omit');
      expect(t.takeException(), isNull);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  test('repite rápido/suave en orden, mantiene ambos ritmos y conserva la receta al reabrir', () {
    final original = _state();
    final before = jsonEncode(original.value);
    for (final omit in [false, true]) {
      final result = repeatRunningEditorGroup(
        original,
        first: 1,
        last: 2,
        repetitions: 3,
        omitLastRecovery: omit,
      );
      final input = projectWorkoutEditorSnapshot(result);
      validateWorkoutDraft(input);
      expect(input.blocks.single.exercises.single.sets, [
        _lap(RunningStepKind.warmup),
        _fast,
        _soft,
        _fast,
        _soft,
        _fast,
        if (!omit) _soft,
        _lap(RunningStepKind.cooldown),
      ]);
      expect(
        projectWorkoutEditorSnapshot(workoutEditorStateFromInput(input)),
        input,
      );
      final wire =
          workoutDraftToJson(input)['blocks'][0]['exercises'][0]['sets']
              as List;
      expect(wire.length, omit ? 7 : 8);
      expect(wire[2]['running_step']['kind'], 'recovery');
      expect(wire[2]['target_pace_min_seconds_per_km'], 300);
      expect(wire[2]['target_pace_max_seconds_per_km'], 320);
      expect(wire.last['running_step']['completion'], 'manual');
    }
    expect(jsonEncode(original.value), before);
  });

  test(
    'separar trote conserva las parejas originales y permite su ritmo propio',
    () {
      final original = _state(attached: true);
      original.value['segments'][1]['countText'] = '2';
      final result = separateRunningEditorRecovery(original, 1);
      final rows = result.value['segments'] as List;
      expect(rows.length, 6);
      for (final i in [2, 4]) {
        expect(rows[i]['stepKind'], 'recovery');
        expect(rows[i]['targetText'], '03:00');
        rows[i]['paceText'] = '05:00';
        rows[i]['paceMaxText'] = '05:20';
      }
      expect(_sets(result), [
        _lap(RunningStepKind.warmup),
        _fast,
        _soft,
        _fast,
        _soft,
        _lap(RunningStepKind.cooldown),
      ]);
      expect(original.value['segments'][1]['recoveryType'], 'jogging');
      expect(original.value['segments'][1]['countText'], '2');
    },
  );

  test(
    'omisión explícita elimina solo la recuperación asociada a la última serie',
    () {
      final result = repeatRunningEditorGroup(
        _state(attached: true),
        first: 1,
        last: 1,
        repetitions: 5,
        omitLastRecovery: true,
      );
      final sets = _sets(result);
      expect(sets.length, 7);
      expect(
        sets.sublist(1, 5).every((s) => s.recoveryDurationSeconds == 180),
        isTrue,
      );
      expect(sets[5].recoveryType, isNull);
      expect(sets[5].targetValue, 240);
      expect(sets.last, _lap(RunningStepKind.cooldown));
    },
  );

  test('un grupo con repeticiones internas se expande por vueltas, nunca por columnas', () {
    final input = _state();
    input.value['segments'][1]['countText'] = '2';
    final result = repeatRunningEditorGroup(
      input,
      first: 1,
      last: 2,
      repetitions: 2,
    );
    expect(_sets(result), [
      _lap(RunningStepKind.warmup),
      _fast,
      _fast,
      _soft,
      _fast,
      _fast,
      _soft,
      _lap(RunningStepKind.cooldown),
    ]);
  });

  test('rechaza límites y omisión de un esfuerzo sin modificar los campos', () {
    final input = _state();
    final before = jsonEncode(input.value);
    for (final action in [
      () => repeatRunningEditorGroup(input, first: 1, last: 2, repetitions: 40),
      () => repeatRunningEditorGroup(input, first: 1, last: 2, repetitions: 0),
      () => repeatRunningEditorGroup(input, first: 2, last: 1, repetitions: 3),
      () => repeatRunningEditorGroup(
        input,
        first: 1,
        last: 1,
        repetitions: 3,
        omitLastRecovery: true,
      ),
      () => separateRunningEditorRecovery(input, 1),
    ]) {
      expect(action, throwsFormatException);
      expect(jsonEncode(input.value), before);
    }
  });

  test(
    'la separación mantiene medidas activas y no inventa ritmo al descanso',
    () {
      for (final type in ['walking', 'passive']) {
        final input = _state(attached: true);
        input.value['segments'][1]['recoveryType'] = type;
        if (type == 'walking') {
          input.value['segments'][1]['recoveryByDistance'] = true;
          input.value['segments'][1]['recoveryTimeText'] = '200';
        }
        final soft = _sets(separateRunningEditorRecovery(input, 1))[2];
        expect(
          soft.runningStep!.kind,
          type == 'walking' ? RunningStepKind.walking : RunningStepKind.rest,
        );
        expect(soft.targetValue, type == 'walking' ? 200 : 180);
        expect(
          soft.targetType,
          type == 'walking'
              ? WorkoutTargetType.distance
              : WorkoutTargetType.duration,
        );
        expect(soft.targetPaceMinSecondsPerKm, isNull);
      }
    },
  );

  test('las acciones conservan un trabajo incompleto sin rellenar valores', () {
    final input = _state(attached: true);
    input.value['segments'][1]['recoveryTimeText'] = '';
    input.value['segments'][1]['paceText'] = '04:';
    final split = separateRunningEditorRecovery(input, 1);
    expect(split.value['segments'][1]['paceText'], '04:');
    expect(split.value['segments'][2]['targetText'], '');
    expect(() => projectWorkoutEditorSnapshot(split), throwsFormatException);
  });

  testWidgets(
    'el creador guarda fartlek con ritmo suave y omisión elegida en el diálogo',
    (t) async {
      t.view.physicalSize = const Size(1200, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(
        MaterialApp(
          home: WorkoutEditorPage(
            title: 'Carrera',
            heading: 'Fartlek',
            instructions: '',
            saveLabel: 'Guardar prueba',
            fixedRunningMode: true,
            initialEditorState: _state(attached: true).value,
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
      Future<void> show(Finder finder) async {
        await t.scrollUntilVisible(
          finder,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pumpAndSettle();
      }

      await show(find.byKey(const ValueKey('running-step-header-1')));
      await t.tap(find.byKey(const ValueKey('running-step-header-1')));
      await t.pumpAndSettle();
      final objective = find.byKey(
        const ValueKey('attached-recovery-objective'),
      );
      await show(objective);
      await t.tap(objective);
      await t.pumpAndSettle();
      await t.tap(find.text('Ritmo').last);
      await t.pumpAndSettle();
      final softCard = find.byKey(const ValueKey('recovery-fields-1'));
      Finder field(String label) => find.descendant(
        of: softCard,
        matching: find.widgetWithText(TextFormField, label),
      );
      await show(field('Ritmo (m:ss/km)'));
      await t.enterText(field('Ritmo (m:ss/km)'), '05:00');
      await t.enterText(field('Hasta (m:ss/km)'), '05:20');
      await show(find.text('Repetir grupo'));
      await t.tap(find.text('Repetir grupo'));
      await t.pumpAndSettle();
      expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      final repetitions = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await t.enterText(repetitions, '3');
      await t.tap(find.text('Omitir última recuperación'));
      await t.tap(find.text('Aplicar'));
      await t.pumpAndSettle();
      await show(find.text('Guardar prueba'));
      await t.tap(find.text('Guardar prueba'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(saved, isNotNull);
      expect(saved!.blocks.single.exercises.single.sets, [
        _lap(RunningStepKind.warmup),
        _fast,
        _soft,
        _fast,
        _soft,
        _fast,
        _lap(RunningStepKind.cooldown),
      ]);
      expect(
        projectWorkoutEditorSnapshot(workoutEditorStateFromInput(saved!)),
        saved,
      );
    },
  );
}
