import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

const input = CreatePersonalWorkoutInput(
  name: 'Sesión inicial',
  blocks: [
    WorkoutBlockDraft(
      name: 'Principal',
      exercises: [
        WorkoutExerciseDraft(
          exerciseId: 'base',
          sets: [
            WorkoutSetDraft(
              targetType: WorkoutTargetType.repetitions,
              targetValue: 8,
              restAfterSeconds: 60,
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('revisar una sesión publicada conserva series sin carga ni RIR', (
    t,
  ) async {
    CreatePersonalWorkoutInput? saved;
    const original = WorkoutTemplate(
      id: 'published',
      name: 'Sesión publicada',
      description: null,
      estimatedDurationMinutes: 20,
      version: 2,
      blocks: [
        WorkoutBlock(
          id: 'block',
          name: 'Principal',
          format: WorkoutBlockFormat.straightSets,
          rounds: 1,
          restAfterSeconds: 0,
          items: [
            WorkoutItem(
              id: 'item',
              exerciseId: 'base',
              exerciseName: 'Ejercicio',
              sets: [
                WorkoutSet(
                  id: 'first',
                  order: 0,
                  restAfterSeconds: 60,
                  targetReps: 8,
                  targetLoadKg: 15,
                  targetRir: 2,
                ),
                WorkoutSet(
                  id: 'second',
                  order: 1,
                  restAfterSeconds: 30,
                  targetReps: 10,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp(
        home: WorkoutEditorPage(
          title: 'Revisar',
          heading: 'Receta',
          instructions: '',
          saveLabel: 'Guardar',
          originalTemplate: original,
          loadExercises: () async => [
            const WorkoutEditorExercise(id: 'base', name: 'Ejercicio'),
          ],
          onSave: (input) async {
            saved = input;
            return 'new-version';
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
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    final sets = saved!.blocks.single.exercises.single.sets;
    expect(sets.map((s) => s.targetValue), [8, 10]);
    expect(sets.map((s) => s.targetLoadKg), [15, null]);
    expect(sets.map((s) => s.targetRir), [2, null]);
    expect(sets.map((s) => s.restAfterSeconds), [60, 30]);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'serializa borradores pendientes antes del guardado final y no los resucita',
    (t) async {
      final firstWrite = Completer<void>();
      final finalSave = Completer<void>();
      final events = <String>[];
      Map<String, dynamic>? stored;
      await t.pumpWidget(
        MaterialApp(
          home: WorkoutEditorPage(
            title: 'Sesión',
            heading: 'Receta',
            instructions: '',
            saveLabel: 'Guardar',
            fixedRunningMode: false,
            initialEditorState: workoutEditorStateFromInput(input).value,
            loadExercises: () async => [
              const WorkoutEditorExercise(id: 'base', name: 'Ejercicio'),
            ],
            saveLocalDraft: (raw) async {
              events.add(raw['nameText'] as String);
              if (events.length == 1) await firstWrite.future;
              stored = raw;
            },
            onSave: (_) async {
              events.add('save');
              stored = null;
              await finalSave.future;
              return 'saved';
            },
            onSaved: (_) => events.add('saved'),
          ),
        ),
      );
      await t.pumpAndSettle();
      final name = find.byKey(const ValueKey('workout-name'));
      await t.enterText(name, 'Primer borrador');
      await t.pump(const Duration(milliseconds: 800));
      await t.enterText(name, 'Último borrador');
      await t.pump(const Duration(milliseconds: 800));
      expect(events, ['Primer borrador']);
      await t.scrollUntilVisible(
        find.text('Guardar'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Guardar'));
      await t.pump();
      expect(events, ['Primer borrador']);
      firstWrite.complete();
      await t.pumpAndSettle();
      expect(events, ['Primer borrador', 'Último borrador', 'save']);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump(const Duration(seconds: 1));
      expect(events, ['Primer borrador', 'Último borrador', 'save']);
      finalSave.complete();
      await t.pumpAndSettle();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(seconds: 2));
      expect(events, ['Primer borrador', 'Último borrador', 'save', 'saved']);
      expect(stored, isNull);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'guarda textos incompletos sin convertirlos en una receta válida',
    (t) async {
      Map<String, dynamic>? stored;
      await t.pumpWidget(
        MaterialApp(
          home: WorkoutEditorPage(
            title: 'Sesión',
            heading: 'Receta',
            instructions: '',
            saveLabel: 'Guardar',
            fixedRunningMode: true,
            loadExercises: () async => [],
            saveLocalDraft: (raw) async => stored = raw,
            onSave: (_) async => throw StateError('No debe publicar'),
            onSaved: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final pace = find.widgetWithText(TextFormField, 'Ritmo (m:ss/km)');
      await t.scrollUntilVisible(
        pace,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(pace, '4');
      await t.pump(const Duration(milliseconds: 800));
      expect(stored!['segments'][0]['paceText'], '00:04');
      expect(stored!['segments'][0]['targetText'], '');
      expect(t.takeException(), isNull);
    },
  );
}
