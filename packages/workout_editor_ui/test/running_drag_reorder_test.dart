import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_step_card.dart';
import 'package:workout_editor_ui/running_reorderable_steps.dart';
import 'package:workout_editor_ui/workout_editor_snapshot.dart';

import 'running_compact_editor_test.dart' show editor, show, open;
import 'running_editor_groups_test.dart' show fixture;
import '../../../test/helpers/performance_visual_review.dart';

Future<void> dragRow(
  WidgetTester t,
  int from,
  int onto, {
  required PointerDeviceKind kind,
  bool after = true,
  bool cancel = false,
}) async {
  final source = find.byKey(ValueKey('running-drag-handle-$from'));
  await show(t, source);
  final card = find.byType(RunningStepCard).at(onto);
  final target = t.getRect(card);
  final destination = Offset(
    target.center.dx,
    after ? target.bottom - 10 : target.top + 10,
  );
  final gesture = await t.startGesture(t.getCenter(source), kind: kind);
  await gesture.moveBy(const Offset(0, 12));
  await t.pump();
  await gesture.moveTo(destination);
  await t.pump(const Duration(milliseconds: 100));
  await capturePerformanceWidget(t, 'running-drag-${kind.name}-$from-$onto');
  if (cancel) {
    await gesture.cancel();
  } else {
    await gesture.up();
  }
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFont);
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    for (final size in [const Size(390, 1100), const Size(1200, 1300)]) {
      testWidgets(
        'arrastrar con ${kind.name} a $size mueve la serie y su recuperación omitida',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final initial = fixture(count: 3, omit: true);
          final original = projectWorkoutEditorSnapshot(initial)
              .blocks
              .single
              .exercises
              .single
              .sets;
          CreatePersonalWorkoutInput? saved;
          Map<String, dynamic>? draft;
          await t.pumpWidget(
            editor(
              initial: initial.value,
              save: (v) => saved = v,
              local: (v) async {
                draft = v;
              },
            ),
          );
          await t.pumpAndSettle();
          await dragRow(t, 1, 2, kind: kind);
          final titles = t
              .widgetList<RunningStepCard>(find.byType(RunningStepCard))
              .map((c) => c.title)
              .toList();
          expect(titles, ['Calentamiento', 'Enfriamiento', 'Carrera × 3']);
          await t.pump(const Duration(seconds: 1));
          expect(draft, isNotNull);
          await show(t, find.text('Guardar carrera'));
          await t.tap(find.text('Guardar carrera'));
          await t.pumpAndSettle();
          final expected = [
            original.first,
            original.last,
            ...original.sublist(1, original.length - 1),
          ];
          expect(saved!.blocks.single.exercises.single.sets, expected);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'cancelar el arrastre no altera la pauta ni escribe el borrador',
    (t) async {
      t.view.physicalSize = const Size(1200, 1300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var writes = 0;
      await t.pumpWidget(
        editor(
          local: (_) async {
            writes++;
          },
        ),
      );
      await t.pumpAndSettle();
      await dragRow(t, 1, 2, kind: PointerDeviceKind.touch, cancel: true);
      await t.pump(const Duration(seconds: 1));
      expect(writes, 0);
      expect(
        t
            .widgetList<RunningStepCard>(find.byType(RunningStepCard))
            .map((c) => c.title),
        ['Calentamiento', 'Carrera × 10', 'Enfriamiento'],
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('mover un tramo abierto conserva el texto incompleto al editar', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(editor());
    await t.pumpAndSettle();
    await open(t, 1);
    final distance = find.widgetWithText(TextFormField, 'Distancia (m)');
    await show(t, distance);
    await t.enterText(distance, '');
    await t.pumpAndSettle();
    await dragRow(t, 1, 0, kind: PointerDeviceKind.mouse, after: false);
    expect(
      t.widgetList<RunningStepCard>(find.byType(RunningStepCard)).first.title,
      'Carrera × 10',
    );
    expect(
      t
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Distancia (m)'),
          )
          .controller!
          .text,
      '',
    );
    expect(
      t
          .widgetList<RunningStepCard>(find.byType(RunningStepCard))
          .first
          .expanded,
      isTrue,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'el arrastre desplaza el formulario exterior y suelta en la fila visible actual',
    (t) async {
      t.view.physicalSize = const Size(390, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final values = List.generate(12, (i) => i);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 180),
                  StatefulBuilder(
                    builder: (context, update) => RunningReorderableSteps(
                      identities: values,
                      onReorder: (from, to) => update(() {
                        final v = values.removeAt(from);
                        values.insert(to, v);
                      }),
                      feedbackBuilder: (_, i) => Text('Tramo ${values[i]}'),
                      itemBuilder: (_, i, handle) => SizedBox(
                        key: ValueKey('row-${values[i]}'),
                        height: 100,
                        child: Row(
                          children: [handle, Text('Tramo ${values[i]}')],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final gesture = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('running-drag-handle-0'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 12));
      await t.pump();
      await gesture.moveTo(const Offset(190, 590));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(controller.offset, greaterThan(150));
      final visible = List.generate(12, (i) => i).where((i) {
        final r = t.getRect(find.byKey(ValueKey('row-$i')));
        return r.top > 100 && r.bottom < 550;
      }).last;
      expect(visible, greaterThan(2));
      final rect = t.getRect(find.byKey(ValueKey('row-$visible')));
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 10));
      await t.pumpAndSettle();
      await gesture.moveBy(const Offset(0, 1));
      await t.pump();
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        values[visible],
        0,
        reason: 'visible $visible, orden $values, scroll ${controller.offset}',
      );
      expect(values.toSet().length, 12);
      final stopped = controller.offset;
      await t.pump(const Duration(seconds: 1));
      expect(controller.offset, stopped);
      expect(t.takeException(), isNull);
    },
  );
}
