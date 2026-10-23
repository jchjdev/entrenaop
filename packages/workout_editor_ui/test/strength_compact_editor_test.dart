import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_card.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';
import 'package:workout_editor_ui/workout_reorderable_cards.dart';

import 'running_compact_editor_test.dart' show show;
import '../../../test/helpers/performance_visual_review.dart';

const formats = [
  WorkoutBlockFormat.straightSets,
  WorkoutBlockFormat.superset,
  WorkoutBlockFormat.circuit,
  WorkoutBlockFormat.intervals,
  WorkoutBlockFormat.emom,
  WorkoutBlockFormat.amrap,
  WorkoutBlockFormat.tabata,
];

CreatePersonalWorkoutInput recipe(
  List<WorkoutBlockFormat> selected,
) => CreatePersonalWorkoutInput(
  name: 'Prueba sintética',
  blocks: [
    for (var b = 0; b < selected.length; b++)
      WorkoutBlockDraft(
        name: 'Bloque ${b + 1}',
        format: selected[b],
        rounds: selected[b] == WorkoutBlockFormat.tabata
            ? 8
            : selected[b] == WorkoutBlockFormat.amrap ||
                  selected[b] == WorkoutBlockFormat.straightSets
            ? 1
            : 3,
        timeCapSeconds: selected[b] == WorkoutBlockFormat.amrap ? 600 : null,
        restAfterSeconds: selected[b] == WorkoutBlockFormat.tabata
            ? 10
            : selected[b] == WorkoutBlockFormat.emom
            ? 60
            : 0,
        exercises: List.generate(
          selected[b] == WorkoutBlockFormat.tabata
              ? 8
              : selected[b] == WorkoutBlockFormat.superset ||
                    selected[b] == WorkoutBlockFormat.circuit
              ? 2
              : 1,
          (e) => WorkoutExerciseDraft(
            exerciseId: 'exercise-$e',
            sets: List.generate(
              selected[b] == WorkoutBlockFormat.tabata ||
                      selected[b] == WorkoutBlockFormat.amrap
                  ? 1
                  : 3,
              (s) => WorkoutSetDraft(
                targetType: selected[b] == WorkoutBlockFormat.tabata
                    ? WorkoutTargetType.duration
                    : WorkoutTargetType.repetitions,
                targetValue: selected[b] == WorkoutBlockFormat.tabata
                    ? 20.0
                    : (8 + e + s).toDouble(),
                restAfterSeconds: selected[b] == WorkoutBlockFormat.straightSets
                    ? 60 + s
                    : 0,
                targetLoadKg: selected[b] == WorkoutBlockFormat.tabata
                    ? null
                    : 10 + e.toDouble(),
                targetRir: selected[b] == WorkoutBlockFormat.tabata ? null : 2,
              ),
            ),
          ),
        ),
      ),
  ],
);

Widget strengthEditor({
  required Map<String, dynamic> initial,
  ValueChanged<CreatePersonalWorkoutInput>? save,
  Future<void> Function(Map<String, dynamic>)? local,
  double scale = 1,
}) => RepaintBoundary(
  key: const ValueKey('review-boundary'),
  child: MaterialApp(
    theme: EntrenaTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: WorkoutEditorPage(
      title: 'Crear sesión',
      heading: 'Fuerza',
      instructions: '',
      fixedRunningMode: false,
      initialEditorState: initial,
      loadExercises: () async => [
        for (var i = 0; i < 8; i++)
          WorkoutEditorExercise(id: 'exercise-$i', name: 'Ejercicio ${i + 1}'),
      ],
      saveLabel: 'Guardar fuerza',
      saveLocalDraft: local,
      onSave: (input) async {
        save?.call(input);
        return 'saved';
      },
      onSaved: (_) {},
    ),
  ),
);

Future<void> toggle(WidgetTester t, int row) async {
  final header = find.byKey(ValueKey('strength-block-header-$row'));
  await show(t, header);
  await t.tap(header);
  await t.pumpAndSettle();
}

Future<void> dragBlock(
  WidgetTester t,
  int from,
  int to,
  PointerDeviceKind kind, {
  bool cancel = false,
}) async {
  final handle = find.byKey(ValueKey('strength-drag-handle-$from'));
  await show(t, handle);
  final rect = t.getRect(find.byType(WorkoutEditorCard).at(to));
  final g = await t.startGesture(t.getCenter(handle), kind: kind);
  await g.moveBy(const Offset(0, 15));
  await t.pump();
  await g.moveTo(
    Offset(rect.center.dx, from < to ? rect.bottom - 10 : rect.top + 10),
  );
  await t.pump(const Duration(milliseconds: 100));
  if (cancel) {
    await g.cancel();
  } else {
    await g.up();
  }
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFont);
  for (final scale in [1.0, 2.0]) {
    testWidgets('acciones de tres ejercicios caben a 320 px / $scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = recipe([WorkoutBlockFormat.circuit]).blocks.single;
      final input = CreatePersonalWorkoutInput(
        name: 'Circuito sintético',
        blocks: [
          WorkoutBlockDraft(
            name: base.name,
            format: base.format,
            rounds: base.rounds,
            exercises: [
              ...base.exercises,
              WorkoutExerciseDraft(
                exerciseId: 'exercise-2',
                sets: base.exercises.first.sets,
              ),
            ],
          ),
        ],
      );
      await t.pumpWidget(
        strengthEditor(
          scale: scale,
          initial: workoutEditorStateFromInput(input).value,
        ),
      );
      await t.pumpAndSettle();
      await show(t, find.text('Posición 2'));
      expect(find.byTooltip('Subir posición'), findsNWidgets(2));
      expect(find.byTooltip('Bajar posición'), findsNWidgets(2));
      await capturePerformanceWidget(t, 'strength-exercise-actions-320-$scale');
      expect(t.takeException(), isNull);
    });
  }
  for (final format in formats) {
    testWidgets('plegar y mover $format conserva la receta completa', (
      t,
    ) async {
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final input = recipe([format, WorkoutBlockFormat.straightSets]);
      final initial = workoutEditorStateFromInput(input);
      final expected = projectWorkoutEditorSnapshot(initial);
      CreatePersonalWorkoutInput? saved;
      var writes = 0;
      await t.pumpWidget(
        strengthEditor(
          initial: initial.value,
          save: (v) => saved = v,
          local: (_) async {
            writes++;
          },
        ),
      );
      await t.pumpAndSettle();
      await toggle(t, 0);
      await toggle(t, 1);
      await toggle(t, 1);
      await t.pump(const Duration(seconds: 1));
      expect(writes, 0, reason: 'El plegado solo cambia la presentación');
      await dragBlock(t, 0, 1, PointerDeviceKind.mouse);
      await t.pump(const Duration(seconds: 1));
      expect(writes, greaterThan(0));
      final button = find.text('Guardar fuerza');
      await show(t, button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(saved!.blocks, expected.blocks.reversed.toList());
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('cancelar con el dedo no modifica ni escribe los bloques', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1500);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var writes = 0;
    await t.pumpWidget(
      strengthEditor(
        initial: workoutEditorStateFromInput(recipe(formats.take(3).toList()))
            .value,
        local: (_) async {
          writes++;
        },
      ),
    );
    await t.pumpAndSettle();
    await toggle(t, 0);
    await dragBlock(t, 0, 2, PointerDeviceKind.touch, cancel: true);
    await t.pump(const Duration(seconds: 1));
    expect(writes, 0);
    expect(
      t.widget<WorkoutEditorCard>(find.byType(WorkoutEditorCard).first).title,
      'Por series · Bloque 1',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'arrastrar incompleto conserva controlador, foco lógico y borrador',
    (t) async {
      t.view.physicalSize = const Size(1200, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Map<String, dynamic>? draft;
      await t.pumpWidget(
        strengthEditor(
          initial: workoutEditorStateFromInput(recipe(formats.take(2).toList()))
              .value,
          local: (v) async {
            draft = v;
          },
        ),
      );
      await t.pumpAndSettle();
      final name = find.byKey(const ValueKey('editor-field-Nombre del bloque'));
      await show(t, name);
      await t.enterText(name, '');
      await t.pump();
      final controller = t.widget<TextField>(name).controller;
      // Se pliega para mover sin intentar proyectar una receta incompleta.
      await toggle(t, 0);
      await dragBlock(t, 0, 1, PointerDeviceKind.touch);
      await toggle(t, 1);
      await t.pump(const Duration(seconds: 1));
      expect(t.widget<TextField>(name).controller, same(controller));
      expect((draft!['blocks'] as List).last['nameText'], '');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'arrastrar ejercicios de superserie conserva A1/A2 y excepciones',
    (t) async {
      t.view.physicalSize = const Size(1200, 2200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final input = recipe([WorkoutBlockFormat.superset]);
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(
        strengthEditor(
          initial: workoutEditorStateFromInput(input).value,
          save: (v) => saved = v,
        ),
      );
      await t.pumpAndSettle();
      final handle = find.byKey(const ValueKey('strength-exercise-handle-0-0'));
      await show(t, handle);
      final reorder = find.byType(WorkoutReorderableCards).last;
      final rect = t.getRect(reorder);
      final g = await t.startGesture(
        t.getCenter(handle),
        kind: PointerDeviceKind.touch,
      );
      await g.moveBy(const Offset(0, 15));
      await t.pump();
      await g.moveTo(Offset(rect.center.dx, rect.bottom - 10));
      await t.pump();
      await g.up();
      await t.pumpAndSettle();
      final button = find.text('Guardar fuerza');
      await show(t, button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(
        saved!.blocks.single.exercises,
        input.blocks.single.exercises.reversed.toList(),
      );
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [320.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('siete formatos con color y plegado a $width / $scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          strengthEditor(
            scale: scale,
            initial: workoutEditorStateFromInput(recipe(formats)).value,
          ),
        );
        await t.pumpAndSettle();
        await toggle(t, 0);
        final cards = t
            .widgetList<WorkoutEditorCard>(find.byType(WorkoutEditorCard))
            .toList();
        expect(cards.length, 7);
        expect(cards.where((c) => c.expanded), isEmpty);
        expect(cards.map((c) => c.color).toSet().length, 7);
        await show(t, find.byKey(const ValueKey('strength-block-header-0')));
        await capturePerformanceWidget(t, 'strength-compact-$width-$scale');
        await toggle(t, 1);
        expect(
          t
              .widgetList<WorkoutEditorCard>(find.byType(WorkoutEditorCard))
              .where((c) => c.expanded)
              .length,
          1,
        );
        await capturePerformanceWidget(t, 'strength-open-$width-$scale');
        expect(t.takeException(), isNull);
      });
    }
  }
}
