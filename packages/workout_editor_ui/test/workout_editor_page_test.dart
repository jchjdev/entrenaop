import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';

import '../../../test/helpers/performance_visual_review.dart';

const _catalog = [
  WorkoutEditorExercise(id: 'base', name: 'Ejercicio de partida'),
  WorkoutEditorExercise(id: 'private', name: 'Ejercicio privado de Alba'),
];

const _original = WorkoutTemplate(
  id: 'original',
  name: 'Sesión de partida',
  description: 'Indicaciones de la receta',
  estimatedDurationMinutes: 30,
  version: 3,
  blocks: [
    WorkoutBlock(
      id: 'block',
      name: 'Bloque principal',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'item',
          exerciseId: 'base',
          exerciseName: 'Ejercicio de partida',
          sets: [
            WorkoutSet(
              id: 'first',
              order: 0,
              targetReps: 10,
              targetLoadKg: 12.5,
              targetRir: 2.5,
              restAfterSeconds: 90,
            ),
            WorkoutSet(
              id: 'second',
              order: 1,
              targetReps: 12,
              targetLoadKg: 15,
              targetRir: 3,
              restAfterSeconds: 60,
            ),
          ],
        ),
      ],
    ),
  ],
);

Widget _app({
  required Future<String> Function(CreatePersonalWorkoutInput) save,
  required ValueChanged<String> saved,
  WorkflowExitController? exit,
  String stamp = '',
  Widget? additionalFields,
  Future<List<WorkoutEditorExercise>> Function()? load,
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
    home: WorkflowExitScope(
      controller: exit ?? WorkflowExitController(),
      child: WorkoutEditorPage(
        loadExercises: load ?? () async => _catalog,
        onSave: save,
        onSaved: saved,
        title: 'Crear sesión privada',
        heading: 'Contenido del preparador',
        instructions: 'Solo para los clientes autorizados.',
        saveLabel: 'Guardar privado',
        originalTemplate: _original,
        additionalFields: additionalFields,
        additionalStateStamp: stamp,
        saveErrorMessage: 'No se pudo guardar el contenido privado.',
      ),
    ),
  ),
);

Future<void> _save(WidgetTester tester) async {
  final button = find.text('Guardar privado');
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final width in [320.0, 390.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('series sin solapar título y etiquetas a $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(save: (_) async => 'saved', saved: (_) {}, scale: scale),
        );
        await tester.pumpAndSettle();
        final title = find.text('Serie 1');
        await tester.scrollUntilVisible(
          title,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        final fields = find.byType(StrengthSetFields).at(1);
        final label = find.descendant(
          of: fields,
          matching: find.text('Objetivo'),
        );
        expect(
          tester.getTopLeft(label).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(title).dy + 6),
        );
        expect(find.text('Valores comunes'), findsOneWidget);
        expect(find.text('Ajustes por serie'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capturePerformanceWidget(
          tester,
          'shared-series-${width.toInt()}-${scale.toInt()}',
        );
      });
    }
  }

  testWidgets('un consumidor sin ADMIN aporta catálogo y recibe receta e ID', (
    tester,
  ) async {
    CreatePersonalWorkoutInput? input;
    String? savedId;
    await tester.pumpWidget(
      _app(
        save: (value) async {
          input = value;
          return 'private-version';
        },
        saved: (id) => savedId = id,
      ),
    );
    await tester.pumpAndSettle();

    final change = find.textContaining('Cambiar ejercicio ·');
    await tester.scrollUntilVisible(
      change,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(change);
    await tester.pumpAndSettle();
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ejercicio privado de Alba'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(savedId, 'private-version');
    expect(input!.name, _original.name);
    expect(input!.blocks.single.exercises.single.exerciseId, 'private');
    expect(input!.blocks.single.exercises.single.sets, const [
      WorkoutSetDraft(
        targetType: WorkoutTargetType.repetitions,
        targetValue: 10,
        targetLoadKg: 12.5,
        targetRir: 2.5,
        restAfterSeconds: 90,
      ),
      WorkoutSetDraft(
        targetType: WorkoutTargetType.repetitions,
        targetValue: 12,
        targetLoadKg: 15,
        targetRir: 3,
        restAfterSeconds: 60,
      ),
    ]);
    expect(find.text('Mostrar en Sesiones de EntrenaOP'), findsNothing);
    // El consumidor decide la navegación: confirmar no cierra el editor común.
    expect(find.byType(WorkoutEditorPage), findsOneWidget);
  });

  testWidgets(
    'un error del consumidor conserva los campos y permite reintentar',
    (tester) async {
      var attempts = 0;
      final savedNames = <String>[];
      final ids = <String>[];
      await tester.pumpWidget(
        _app(
          save: (value) async {
            savedNames.add(value.name);
            if (++attempts == 1) throw StateError('Sin conexión');
            return 'confirmed';
          },
          saved: ids.add,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Nombre de la sesión',
        ),
        'Nombre conservado',
      );
      await _save(tester);
      expect(
        find.text('No se pudo guardar el contenido privado.'),
        findsOneWidget,
      );
      expect(ids, isEmpty);
      await _save(tester);
      expect(savedNames, ['Nombre conservado', 'Nombre conservado']);
      expect(ids, ['confirmed']);
    },
  );

  testWidgets('la validación común impide enviar una receta inválida', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        save: (_) async {
          calls++;
          return 'unexpected';
        },
        saved: (_) => fail('No debe confirmar una receta inválida'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Nombre de la sesión',
      ),
      'ab',
    );
    await _save(tester);
    expect(calls, 0);
    expect(
      find.text('El nombre debe tener entre 3 y 80 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('guardado pendiente bloquea salida y envíos repetidos', (
    tester,
  ) async {
    final pending = Completer<String>();
    final exit = WorkflowExitController();
    var calls = 0;
    final ids = <String>[];
    await tester.pumpWidget(
      _app(
        exit: exit,
        save: (_) {
          calls++;
          return pending.future;
        },
        saved: ids.add,
      ),
    );
    await tester.pumpAndSettle();
    await _save(tester);
    expect(await exit.onExit!(), isFalse);
    expect(find.text('Guardando…'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardando…'),
    );
    expect(button.onPressed, isNull);
    expect(calls, 1);
    expect(ids, isEmpty);
    pending.complete('saved');
    await tester.pumpAndSettle();
    expect(ids, ['saved']);
    expect(await exit.onExit!(), isTrue);
  });

  testWidgets(
    'los campos del consumidor conservan receta, catálogo y guard de salida',
    (tester) async {
      var checked = false;
      var loads = 0;
      final exit = WorkflowExitController();
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, update) => _app(
            exit: exit,
            load: () async {
              loads++;
              return _catalog;
            },
            save: (_) async => 'saved',
            saved: (_) {},
            stamp: checked.toString(),
            additionalFields: SwitchListTile(
              title: const Text('Opción del consumidor'),
              value: checked,
              onChanged: (value) => update(() => checked = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await exit.onExit!(), isTrue);
      await tester.scrollUntilVisible(
        find.text('Opción del consumidor'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Opción del consumidor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opción del consumidor'));
      await tester.pumpAndSettle();
      expect(checked, isTrue);
      expect(loads, 1);
      final leaving = exit.onExit!();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(await leaving, isFalse);
      await _save(tester);
      expect(await exit.onExit!(), isTrue);
    },
  );
}
