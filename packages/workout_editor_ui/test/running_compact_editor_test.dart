import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_editor_groups.dart';
import 'package:workout_editor_ui/running_step_card.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import 'running_editor_groups_test.dart' show fixture;
import '../../../test/helpers/performance_visual_review.dart';

Future<void> show(WidgetTester t, Finder target) async {
  if (target.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
}

Future<void> open(WidgetTester t, int row) async {
  final target = find.byKey(ValueKey('running-step-header-$row'));
  await show(t, target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> chooseObjective(
  WidgetTester t,
  Finder parent,
  String label,
) async {
  final field = find
      .descendant(
        of: parent,
        matching: find.byType(DropdownButtonFormField<bool>),
      )
      .first;
  await show(t, field);
  await t.tap(field);
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

Widget editor({
  ValueChanged<CreatePersonalWorkoutInput>? save,
  Future<void> Function(Map<String, dynamic>)? local,
  double scale = 1,
  Map<String, dynamic>? initial,
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
      title: 'Crear sesión privada',
      heading: 'Carrera',
      instructions: '',
      fixedRunningMode: true,
      initialEditorState: initial ?? fixture().value,
      loadExercises: () async => [],
      saveLabel: 'Guardar carrera',
      saveLocalDraft: local,
      onSave: (input) async {
        save?.call(input);
        return 'saved';
      },
      onSaved: (_) {},
    ),
  ),
);

void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('diez series compactas a $width, texto $scale', (t) async {
        await t.runAsync(loadReviewFont);
        t.view.physicalSize = Size(width, width >= 1000 ? 1000 : 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(editor(scale: scale));
        await t.pumpAndSettle();
        expect(find.byType(RunningStepCard), findsNWidgets(3));
        expect(find.text('Carrera × 10'), findsOneWidget);
        expect(
          find.textContaining('Rec. 01:30 min · 05:00–05:30 min/km'),
          findsOneWidget,
        );
        expect(find.text('Editar recuperación como paso'), findsNothing);
        expect(find.text('Ritmo (m:ss/km)'), findsNothing);
        await show(t, find.byKey(const ValueKey('running-step-header-1')));
        await capturePerformanceWidget(
          t,
          'running-compact-$width-$scale-summary',
        );
        await open(t, 1);
        expect(
          t
              .widgetList<RunningStepCard>(find.byType(RunningStepCard))
              .where((c) => c.expanded)
              .length,
          1,
        );
        final work = find.byKey(const ValueKey('work-fields-1'));
        await show(t, work);
        await capturePerformanceWidget(
          t,
          'running-compact-$width-$scale-editor',
        );
        expect(t.takeException(), isNull);
        await open(t, 0);
        expect(
          t
              .widgetList<RunningStepCard>(find.byType(RunningStepCard))
              .where((c) => c.expanded)
              .length,
          1,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('Sin objetivo oculta campos y retira solo los ritmos elegidos', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    CreatePersonalWorkoutInput? saved;
    await t.pumpWidget(editor(save: (value) => saved = value));
    await t.pumpAndSettle();
    await open(t, 1);
    await chooseObjective(
      t,
      find.byKey(const ValueKey('recovery-fields-1')),
      'Sin objetivo',
    );
    expect(find.text('Ritmo (m:ss/km)'), findsOneWidget);
    await chooseObjective(
      t,
      find.byKey(const ValueKey('work-fields-1')),
      'Sin objetivo',
    );
    expect(find.text('Ritmo (m:ss/km)'), findsNothing);
    await show(t, find.text('Guardar carrera'));
    await t.tap(find.text('Guardar carrera'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(saved, isNotNull);
    final sets = saved!.blocks.single.exercises.single.sets;
    expect(sets.length, 22);
    expect(sets.every((s) => s.targetPaceMinSecondsPerKm == null), isTrue);
    expect(sets[1].targetValue, 400);
    expect(sets[2].targetValue, 90);
  });
  testWidgets(
    'plegar no ensucia el borrador y editar aplica a las diez series',
    (t) async {
      t.view.physicalSize = const Size(1200, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var writes = 0;
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(
        editor(
          local: (_) async {
            writes++;
          },
          save: (value) => saved = value,
        ),
      );
      await t.pumpAndSettle();
      await open(t, 1);
      await open(t, 1);
      await t.pump(const Duration(seconds: 1));
      expect(writes, 0);
      await open(t, 1);
      final distance = find.descendant(
        of: find.byKey(const ValueKey('work-fields-1')),
        matching: find.widgetWithText(TextFormField, 'Distancia (m)'),
      );
      await show(t, distance);
      await t.enterText(distance, '600');
      await t.pumpAndSettle();
      await open(t, 1);
      await open(t, 1);
      expect(t.widget<TextFormField>(distance).controller!.text, '600');
      await show(t, find.text('Guardar carrera'));
      await t.tap(find.text('Guardar carrera'));
      await t.pumpAndSettle();
      final sets = saved!.blocks.single.exercises.single.sets;
      expect(
        sets
            .where((s) => s.runningStep?.kind == RunningStepKind.run)
            .every((s) => s.targetValue == 600),
        isTrue,
      );
      expect(
        sets
            .where((s) => s.runningStep?.kind == RunningStepKind.recovery)
            .every((s) => s.targetValue == 90),
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'una repetición puede tener una excepción sin cambiar las otras nueve',
    (t) async {
      t.view.physicalSize = const Size(1200, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(editor(save: (value) => saved = value));
      await t.pumpAndSettle();
      final menu = find.byKey(const ValueKey('running-step-menu-1'));
      await show(t, menu);
      await t.tap(menu);
      await t.pumpAndSettle();
      await t.tap(find.text('Editar repeticiones por separado'));
      await t.pumpAndSettle();
      expect(find.byType(RunningStepCard), findsNWidgets(12));
      await open(t, 2);
      final recovery = find.byKey(const ValueKey('recovery-fields-3'));
      final fast = find.descendant(
        of: recovery,
        matching: find.widgetWithText(TextFormField, 'Ritmo (m:ss/km)'),
      );
      final slow = find.descendant(
        of: recovery,
        matching: find.widgetWithText(TextFormField, 'Hasta (m:ss/km)'),
      );
      await show(t, fast);
      await t.enterText(fast, '05:55');
      await t.enterText(slow, '06:10');
      await t.pumpAndSettle();
      await show(t, find.text('Guardar carrera'));
      await t.tap(find.text('Guardar carrera'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final sets = saved!.blocks.single.exercises.single.sets;
      expect(sets[4].targetPaceMinSecondsPerKm, 355);
      expect(sets[2].targetPaceMinSecondsPerKm, 300);
      expect(sets[6].targetPaceMinSecondsPerKm, 300);
      expect(
        runningEditorGroups(workoutEditorStateFromInput(saved!)).length,
        5,
      );
    },
  );
  testWidgets(
    'recuperación con ritmo conserva diez series y la última omitida',
    (t) async {
      t.view.physicalSize = const Size(1200, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final initial = fixture(count: 1).value;
      final rows = (initial['segments'] as List).cast<Map>();
      initial['segments'] = [
        rows.first,
        {
          ...rows[1],
          'countText': '9',
          'recoveryType': 'jogging',
          'recoveryTimeText': '01:30',
        },
        {...rows[1], 'recoveryTimeText': ''},
        rows.last,
      ];
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(editor(initial: initial, save: (v) => saved = v));
      await t.pumpAndSettle();
      expect(find.byType(RunningStepCard), findsNWidgets(3));
      await open(t, 1);
      final objective = find.byKey(
        const ValueKey('attached-recovery-objective'),
      );
      await show(t, objective);
      await t.tap(objective);
      await t.pumpAndSettle();
      await t.tap(find.text('Ritmo').last);
      await t.pumpAndSettle();
      expect(find.byType(RunningStepCard), findsNWidgets(3));
      expect(find.text('Carrera × 10'), findsOneWidget);
      final child = find.byKey(const ValueKey('recovery-fields-1'));
      final pace = find.descendant(
        of: child,
        matching: find.widgetWithText(TextFormField, 'Ritmo (m:ss/km)'),
      );
      await show(t, pace);
      await t.enterText(pace, '06:00');
      await t.pumpAndSettle();
      await show(t, find.text('Guardar carrera'));
      await t.tap(find.text('Guardar carrera'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final sets = saved!.blocks.single.exercises.single.sets;
      expect(sets.length, 21);
      expect(
        sets.where((s) => s.runningStep?.kind == RunningStepKind.run).length,
        10,
      );
      expect(
        sets
            .where((s) => s.runningStep?.kind == RunningStepKind.recovery)
            .length,
        9,
      );
      expect(sets[18].targetPaceMinSecondsPerKm, 360);
      expect(sets[19].runningStep?.kind, RunningStepKind.run);
      expect(
        runningEditorGroups(
          workoutEditorStateFromInput(saved!),
        )[1].omitLastRecovery,
        isTrue,
      );
    },
  );
}
