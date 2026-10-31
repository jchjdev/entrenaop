import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_format_field.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';

import '../../../test/helpers/performance_visual_review.dart';
import 'exercise_preferences_controller_test.dart' show PreferenceSource;

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
  Future<WorkoutEditorExercise?> Function(BuildContext)? create,
  ExerciseCatalogPreferences? preferences,
  Future<List<WorkoutTemplate>> Function()? warmups,
  double scale = 1,
  WorkoutTemplate original = _original,
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
        loadWarmups: warmups,
        onCreateExercise: create,
        exercisePreferences: preferences,
        onSave: save,
        onSaved: saved,
        title: 'Crear sesión privada',
        heading: 'Contenido del preparador',
        instructions: 'Solo para los clientes autorizados.',
        saveLabel: 'Guardar privado',
        originalTemplate: original,
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

Future<void> _chooseFormat(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final selector = find.byType(WorkoutFormatField);
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

WorkoutTemplate _withItems(List<WorkoutItem> items) => WorkoutTemplate(
  id: _original.id,
  name: _original.name,
  description: _original.description,
  estimatedDurationMinutes: 30,
  version: 3,
  blocks: [
    WorkoutBlock(
      id: 'block',
      name: 'Bloque principal',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: items,
    ),
  ],
);

Future<void> _setField(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'la fila vacía abre directamente el selector y el bloque muestra su configuración',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1600, 1100));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        ProfessionalWorkspaceScope(
          desktop: true,
          child: _app(save: (_) async => 's', saved: (_) {}),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Añadir ejercicio o estación'));
      await t.pumpAndSettle();
      final row = find.text('Elegir ejercicio').last;
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.text('Buscar ejercicio'), findsOneWidget);
      await t.tap(find.text('Ejercicio privado de Alba').last);
      await t.pumpAndSettle();
      expect(find.text('Buscar ejercicio'), findsNothing);
      final tile = t.widget<ExpansionTile>(
        find.widgetWithText(ExpansionTile, 'Configuración del bloque'),
      );
      expect(tile.initiallyExpanded, isTrue);
      expect(find.textContaining('Ejercicio privado de Alba'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'inserta el calentamiento como copia y conserva receta y dosis diferentes',
    (t) async {
      final warmup = WorkoutTemplate(
        id: 'warmup',
        name: 'Activación general',
        description: null,
        estimatedDurationMinutes: 5,
        version: 1,
        blocks: [
          WorkoutBlock(
            id: 'warm-block',
            name: 'Movilidad',
            format: WorkoutBlockFormat.warmUp,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              const WorkoutItem(
                id: 'first',
                exerciseId: 'base',
                exerciseName: 'Base',
                sets: [
                  WorkoutSet(
                    id: 'a',
                    order: 0,
                    targetReps: 8,
                    restAfterSeconds: 20,
                  ),
                  WorkoutSet(
                    id: 'b',
                    order: 1,
                    targetReps: 9,
                    restAfterSeconds: 30,
                  ),
                ],
              ),
              const WorkoutItem(
                id: 'second',
                exerciseId: 'private',
                exerciseName: 'Privado',
                sets: [
                  WorkoutSet(
                    id: 'c',
                    order: 0,
                    targetReps: 12,
                    restAfterSeconds: 40,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      CreatePersonalWorkoutInput? result;
      await t.pumpWidget(
        _app(
          save: (input) async {
            result = input;
            return 'saved';
          },
          saved: (_) {},
          warmups: () async => [warmup],
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Insertar calentamiento'));
      await t.pumpAndSettle();
      await t.tap(find.text('Insertar calentamiento'));
      await t.pumpAndSettle();
      await t.tap(find.text('Activación general'));
      await t.pumpAndSettle();
      await _save(t);
      expect(result, isNotNull);
      expect(result!.blocks.length, 2);
      expect(result!.blocks.first.name, 'Calentamiento · Movilidad');
      expect(result!.blocks.first.exercises.first.sets.length, 2);
      expect(result!.blocks.first.exercises[1].sets.length, 1);
      expect(
        result!.blocks.first.exercises.first.sets.map((e) => e.targetValue),
        [8, 9],
      );
      expect(result!.blocks.last.name, 'Bloque principal');
      expect(warmup.blocks.single.format, WorkoutBlockFormat.warmUp);
      expect(warmup.blocks.single.items.first.sets.first.targetReps, 8);
      expect(t.takeException(), isNull);
    },
  );

  setUpAll(() => loadReviewFont(always: true));
  testWidgets(
    'catálogo activo sin el ejercicio conserva el nombre original como referencia',
    (tester) async {
      await tester.pumpWidget(
        _app(
          save: (_) async => 's',
          saved: (_) {},
          load: () async => const [
            WorkoutEditorExercise(id: 'available', name: 'Disponible'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.text('Cambiar ejercicio · Ejercicio de partida');
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      expect(choose, findsOneWidget);
      expect(
        find.text('Retirado de la biblioteca · se conserva en esta receta.'),
        findsOneWidget,
      );
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Ejercicio de partida'), findsNothing);
      expect(find.text('Disponible'), findsOneWidget);
    },
  );
  testWidgets(
    'ejercicio retirado conserva la receta pero no aparece para volver a elegirlo',
    (tester) async {
      await tester.pumpWidget(
        _app(
          save: (_) async => 's',
          saved: (_) {},
          load: () async => const [
            WorkoutEditorExercise(
              id: 'base',
              name: 'Ejercicio conservado',
              selectable: false,
            ),
            WorkoutEditorExercise(
              id: 'available',
              name: 'Ejercicio disponible',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.text('Cambiar ejercicio · Ejercicio conservado');
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      expect(
        find.text('Retirado de la biblioteca · se conserva en esta receta.'),
        findsOneWidget,
      );
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Ejercicio conservado'), findsNothing);
      expect(find.text('Ejercicio disponible'), findsOneWidget);
      await tester.tap(find.text('Ejercicio disponible'));
      await tester.pumpAndSettle();
      expect(
        find.text('Cambiar ejercicio · Ejercicio disponible'),
        findsOneWidget,
      );
      expect(
        find.text('Retirado de la biblioteca · se conserva en esta receta.'),
        findsNothing,
      );
    },
  );

  testWidgets('guardar exige recuperar o sustituir el ejercicio retirado', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(
      _app(
        save: (_) async {
          writes++;
          return 's';
        },
        saved: (_) {},
        load: () async => const [
          WorkoutEditorExercise(
            id: 'base',
            name: 'Ejercicio conservado',
            selectable: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _save(tester);
    expect(writes, 0);
    final error = find.textContaining(
      'Hay ejercicios retirados en esta receta:',
    );
    await tester.scrollUntilVisible(
      error,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(find.textContaining('Ejercicio conservado'), findsWidgets);
  });

  testWidgets('biblioteca arrastrable no ofrece referencias retiradas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProfessionalWorkspaceScope(
        desktop: true,
        child: _app(
          save: (_) async => 's',
          saved: (_) {},
          load: () async => const [
            WorkoutEditorExercise(
              id: 'base',
              name: 'Ejercicio conservado',
              selectable: false,
            ),
            WorkoutEditorExercise(
              id: 'available',
              name: 'Ejercicio disponible',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final library = find.byType(ProfessionalLibraryPane<WorkoutEditorExercise>);
    expect(library, findsOneWidget);
    expect(
      find.descendant(of: library, matching: find.text('Ejercicio conservado')),
      findsNothing,
    );
    expect(
      find.descendant(of: library, matching: find.text('Ejercicio disponible')),
      findsOneWidget,
    );
    expect(find.textContaining('Ejercicio conservado'), findsWidgets);
  });

  testWidgets(
    'solo aceptar ejercicio registra reciente una vez; cancelar no registra',
    (tester) async {
      final source = PreferenceSource();
      await tester.pumpWidget(
        _app(save: (_) async => 's', saved: (_) {}, preferences: source),
      );
      await tester.pumpAndSettle();
      final choose = find.textContaining('Cambiar ejercicio ·');
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      await tester.tap(choose);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Alba');
      await tester.pumpAndSettle();
      expect(source.selections, isEmpty);
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(source.selections, isEmpty);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ejercicio privado de Alba'));
      await tester.pumpAndSettle();
      expect(source.selections, hasLength(1));
      expect(source.selections.single.$1, 'private');
      expect(
        find.textContaining('Cambiar ejercicio · Ejercicio privado de Alba'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'selector real con preferencias y fallo cabe a 320 px texto doble',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          save: (_) async => 's',
          saved: (_) {},
          scale: 2,
          preferences: PreferenceSource()..failRead = true,
          create: (_) async => null,
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.textContaining('Cambiar ejercicio ·');
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturePerformanceWidget(
        tester,
        'exercise-picker-preferences-error-320-2x',
      );
    },
  );
  testWidgets('selector con filtros y creación cabe en móvil con texto doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        save: (_) async => 's',
        saved: (_) {},
        scale: 2,
        create: (_) async => null,
        preferences: PreferenceSource(),
        load: () async => const [
          WorkoutEditorExercise(
            id: 'base',
            name: 'Ejercicio de partida',
            muscleGroups: ['Glúteos'],
            equipment: ['Banda'],
          ),
          WorkoutEditorExercise(
            id: 'private',
            name: 'Otro',
            muscleGroups: ['Espalda'],
            equipment: ['Polea'],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final choose = find.textContaining('Cambiar ejercicio ·');
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.text('Crear ejercicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capturePerformanceWidget(tester, 'exercise-picker-320-2x');
  });
  testWidgets(
    'crear dentro del selector conserva la receta y selecciona el UUID confirmado',
    (tester) async {
      CreatePersonalWorkoutInput? saved;
      await tester.pumpWidget(
        _app(
          save: (v) async {
            saved = v;
            return 's';
          },
          saved: (_) {},
          create: (_) async => const WorkoutEditorExercise(
            id: 'created',
            name: 'Nuevo ejercicio propio',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choose = find.textContaining('Cambiar ejercicio ·');
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      await tester.tap(choose);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear ejercicio'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cambiar ejercicio · Nuevo ejercicio propio'),
        findsOneWidget,
      );
      await _save(tester);
      final sets = saved!.blocks.single.exercises.single.sets;
      expect(saved!.blocks.single.exercises.single.exerciseId, 'created');
      expect(saved!.name, _original.name);
      expect(sets.map((s) => s.targetValue), [10, 12]);
      expect(sets.map((s) => s.targetRir), [2.5, 3]);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'crear ${fails ? 'falla' : 'se cancela'} sin perder ejercicio ni series',
      (tester) async {
        CreatePersonalWorkoutInput? saved;
        await tester.pumpWidget(
          _app(
            save: (v) async {
              saved = v;
              return 's';
            },
            saved: (_) {},
            create: (_) async {
              if (fails) throw StateError('red');
              return null;
            },
          ),
        );
        await tester.pumpAndSettle();
        final choose = find.textContaining('Cambiar ejercicio ·');
        await tester.ensureVisible(choose);
        await tester.pumpAndSettle();
        await tester.tap(choose);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Crear ejercicio'));
        await tester.pumpAndSettle();
        await _save(tester);
        expect(saved!.blocks.single.exercises.single.exerciseId, 'base');
        expect(
          saved!.blocks.single.exercises.single.sets.map((s) => s.targetValue),
          [10, 12],
        );
      },
    );
  }

  testWidgets('catálogo vacío permite crear sin inventar otros ejercicios', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        save: (_) async => 's',
        saved: (_) {},
        load: () async => [],
        create: (_) async => const WorkoutEditorExercise(
          id: 'first',
          name: 'Primero autorizado',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final choose = find.textContaining('Cambiar ejercicio ·');
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear ejercicio'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cambiar ejercicio · Primero autorizado'),
      findsOneWidget,
    );
  });

  testWidgets(
    'duplicar posición copia excepciones y permite editarlas independientemente',
    (tester) async {
      CreatePersonalWorkoutInput? saved;
      await tester.pumpWidget(
        _app(
          save: (v) async {
            saved = v;
            return 's';
          },
          saved: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final duplicate = find.byTooltip('Duplicar posición');
      await tester.ensureVisible(duplicate);
      await tester.pumpAndSettle();
      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      await _setField(
        tester,
        find.widgetWithText(TextFormField, 'Cantidad').last,
        '17',
      );
      await _save(tester);
      final exercises = saved!.blocks.single.exercises;
      expect(exercises.length, 2);
      expect(exercises.first.sets.map((s) => s.targetValue), [10, 12]);
      expect(exercises.last.sets.map((s) => s.targetValue), [17, 12]);
      expect(exercises.last.sets.map((s) => s.targetLoadKg), [12.5, 15]);
      expect(exercises.last.sets.map((s) => s.restAfterSeconds), [90, 60]);
    },
  );

  testWidgets(
    'duplicar bloque conserva la receta y limpia los huecos automáticos al salir de Tabata',
    (tester) async {
      CreatePersonalWorkoutInput? saved;
      await tester.pumpWidget(
        _app(
          save: (v) async {
            saved = v;
            return 's';
          },
          saved: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      await _chooseFormat(tester, 'Tabata · 8 × 20/10');
      final duplicate = find.byTooltip('Acciones del bloque 1');
      await tester.ensureVisible(duplicate);
      await tester.pumpAndSettle();
      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicar bloque'));
      await tester.pumpAndSettle();
      final secondFormat = find.byType(WorkoutFormatField).last;
      await tester.ensureVisible(secondFormat);
      await tester.pumpAndSettle();
      await tester.tap(secondFormat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Series convencionales').last);
      await tester.pumpAndSettle();
      // Se quita el original Tabata para guardar únicamente la copia revisada.
      final remove = find.byTooltip('Acciones del bloque 1');
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar bloque'));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(saved!.blocks.single.exercises.length, 1);
      expect(
        saved!.blocks.single.exercises.single.sets.map((s) => s.targetValue),
        [10, 12],
      );
    },
  );
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

  testWidgets(
    'salir de Tabata retira sus huecos automáticos y conserva la receta original',
    (tester) async {
      CreatePersonalWorkoutInput? input;
      await tester.pumpWidget(
        _app(
          save: (value) async {
            input = value;
            return 'saved';
          },
          saved: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await _chooseFormat(tester, 'Tabata · 8 × 20/10');
        expect(find.text('Intervalo 8'), findsOneWidget);
        await _chooseFormat(tester, 'Series convencionales');
        expect(find.text('Posición 2'), findsNothing);
      }
      await _save(tester);
      expect(input!.blocks.single.format, WorkoutBlockFormat.straightSets);
      expect(input!.blocks.single.exercises.single.exerciseId, 'base');
      expect(input!.blocks.single.exercises.single.sets.length, 2);
      expect(
        input!.blocks.single.exercises.single.sets.first.targetLoadKg,
        12.5,
      );
      expect(input!.blocks.single.exercises.single.sets.first.targetRir, 2.5);
      expect(input!.blocks.single.exercises.single.sets.first.targetValue, 10);
    },
  );

  testWidgets(
    'Tabata permite volver directamente a intervalos con un ejercicio',
    (tester) async {
      CreatePersonalWorkoutInput? input;
      await tester.pumpWidget(
        _app(
          save: (value) async {
            input = value;
            return 'saved';
          },
          saved: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      await _chooseFormat(tester, 'Tabata · 8 × 20/10');
      await _chooseFormat(tester, 'Intervalos de trabajo');
      expect(find.text('Posición 2'), findsNothing);
      await _save(tester);
      expect(input!.blocks.single.format, WorkoutBlockFormat.intervals);
      expect(input!.blocks.single.exercises.single.exerciseId, 'base');
    },
  );

  testWidgets(
    'los ejercicios elegidos en los intervalos de Tabata se conservan al salir',
    (tester) async {
      CreatePersonalWorkoutInput? input;
      await tester.pumpWidget(
        _app(
          save: (value) async {
            input = value;
            return 'saved';
          },
          saved: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      await _chooseFormat(tester, 'Tabata · 8 × 20/10');
      final search = find.text('Buscar ejercicio del catálogo').last;
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      await tester.tap(search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ejercicio privado de Alba'));
      await tester.pumpAndSettle();
      await _chooseFormat(tester, 'Series convencionales');
      expect(find.text('Posición 2'), findsOneWidget);
      expect(find.text('Posición 3'), findsNothing);
      expect(
        find.textContaining('Cambiar ejercicio · Ejercicio privado de Alba'),
        findsOneWidget,
      );
      expect(
        find.text('Intervalos de trabajo admite un solo ejercicio.'),
        findsOneWidget,
      );
      final field = tester.widget<DropdownButton<WorkoutBlockFormat>>(
        find.descendant(
          of: find.byType(WorkoutFormatField),
          matching: find.byType(DropdownButton<WorkoutBlockFormat>),
        ),
      );
      expect(
        field.items!
            .singleWhere((item) => item.value == WorkoutBlockFormat.intervals)
            .enabled,
        isFalse,
      );
      final amount = find.widgetWithText(TextFormField, 'Cantidad').last;
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '12');
      await _save(tester);
      expect(input!.blocks.single.exercises.map((e) => e.exerciseId), [
        'base',
        'private',
      ]);
      expect(input!.blocks.single.exercises.last.sets.first.targetValue, 12);
    },
  );

  testWidgets(
    'un hueco automático con valores escritos no se elimina al cambiar de formato',
    (tester) async {
      await tester.pumpWidget(_app(save: (_) async => 'saved', saved: (_) {}));
      await tester.pumpAndSettle();
      await _chooseFormat(tester, 'Superserie');
      final amount = find.widgetWithText(TextFormField, 'Cantidad').last;
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '17');
      await tester.pumpAndSettle();
      expect(
        find.text('Intervalos de trabajo admite un solo ejercicio.'),
        findsOneWidget,
      );
      await _chooseFormat(tester, 'Tabata · 8 × 20/10');
      await _chooseFormat(tester, 'Series convencionales');
      expect(find.text('Posición 2'), findsOneWidget);
      expect(find.text('Posición 3'), findsNothing);
      final targetFields = tester.widgetList<StrengthSetFields>(
        find.byType(StrengthSetFields),
      );
      expect(targetFields.last.targetText, '17');
    },
  );

  const changingFormats = [
    'Superserie',
    'Circuito',
    'EMOM · cada minuto',
    'AMRAP · máximas vueltas',
  ];
  for (final from in changingFormats) {
    for (final to in changingFormats.where((value) => value != from)) {
      testWidgets(
        '$from → $to → series conserva ejercicios, dosis y excepciones',
        (tester) async {
          CreatePersonalWorkoutInput? input;
          await tester.pumpWidget(
            _app(
              save: (value) async {
                input = value;
                return 'saved';
              },
              saved: (_) {},
            ),
          );
          await tester.pumpAndSettle();
          await _chooseFormat(tester, from);
          await _chooseFormat(tester, to);
          await _chooseFormat(tester, 'Series convencionales');
          expect(find.text('Posición 2'), findsNothing);
          await _save(tester);
          final block = input!.blocks.single;
          expect(block.format, WorkoutBlockFormat.straightSets);
          expect(block.rounds, 1);
          expect(block.restAfterSeconds, 0);
          expect(block.timeCapSeconds, isNull);
          final sets = block.exercises.single.sets;
          expect(sets.map((set) => set.targetValue), [10, 12]);
          expect(sets.map((set) => set.targetLoadKg), [12.5, 15]);
          expect(sets.map((set) => set.targetRir), [2.5, 3]);
          expect(sets.map((set) => set.restAfterSeconds), [90, 60]);
        },
      );
    }
  }

  for (final targetFormat in changingFormats) {
    testWidgets(
      '$targetFormat guarda solo rondas, descanso y límite que le corresponden',
      (tester) async {
        CreatePersonalWorkoutInput? input;
        await tester.pumpWidget(
          _app(
            original: _withItems(
              List.filled(2, _original.blocks.single.items.single),
            ),
            save: (value) async {
              input = value;
              return 'saved';
            },
            saved: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        await _chooseFormat(tester, 'Superserie');
        await _setField(tester, find.widgetWithText(TextField, 'Rondas'), '3');
        await _setField(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.helperText == 'Entre rondas · min:seg',
          ),
          '00:37',
        );
        await _chooseFormat(tester, 'AMRAP · máximas vueltas');
        await _setField(
          tester,
          find.widgetWithText(TextField, 'Límite global'),
          '07:00',
        );
        await _chooseFormat(tester, 'EMOM · cada minuto');
        await _chooseFormat(tester, targetFormat);
        await _save(tester);
        expect(input, isNotNull);
        final block = input!.blocks.single;
        final amrap = targetFormat.startsWith('AMRAP');
        final emom = targetFormat.startsWith('EMOM');
        expect(block.rounds, amrap ? 1 : 3);
        expect(
          block.restAfterSeconds,
          amrap
              ? 0
              : emom
              ? 60
              : 37,
        );
        expect(block.timeCapSeconds, amrap ? 420 : isNull);
        expect(block.exercises.length, 2);
        for (final exercise in block.exercises) {
          expect(exercise.sets.length, amrap ? 1 : 3);
          expect(
            exercise.sets.every(
              (set) => set.restAfterSeconds == (amrap || emom ? 0 : 90),
            ),
            isTrue,
          );
        }
        await _chooseFormat(tester, 'Series convencionales');
        await _save(tester);
        expect(
          input!.blocks.single.exercises.first.sets.map(
            (set) => set.restAfterSeconds,
          ),
          [90, 60],
        );
      },
    );
  }

  for (final format in ['Tabata · 8 × 20/10', 'AMRAP · máximas vueltas']) {
    testWidgets(
      '$format ignora excepciones ocultas y las recupera al volver a series',
      (tester) async {
        CreatePersonalWorkoutInput? input;
        final tabata = format.startsWith('Tabata');
        final original = tabata
            ? _withItems(List.filled(8, _original.blocks.single.items.single))
            : _original;
        await tester.pumpWidget(
          _app(
            original: original,
            save: (value) async {
              input = value;
              return 'saved';
            },
            saved: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        final firstSeries = find.byType(StrengthSetFields).at(1);
        await _setField(
          tester,
          find.descendant(
            of: firstSeries,
            matching: find.widgetWithText(TextFormField, 'Objetivo'),
          ),
          '7',
        );
        await _setField(
          tester,
          find.descendant(
            of: firstSeries,
            matching: find.widgetWithText(TextFormField, 'Carga'),
          ),
          '24',
        );
        await _setField(
          tester,
          find.descendant(
            of: firstSeries,
            matching: find.widgetWithText(TextFormField, 'Descanso'),
          ),
          '00:45',
        );
        await _chooseFormat(tester, format);
        await _save(tester);
        expect(input, isNotNull);
        final set = input!.blocks.single.exercises.first.sets.single;
        expect(set.targetValue, tabata ? 20 : 10);
        expect(
          set.targetType,
          tabata ? WorkoutTargetType.duration : WorkoutTargetType.repetitions,
        );
        expect(set.targetLoadKg, tabata ? isNull : 12.5);
        expect(set.targetRir, tabata ? isNull : 2.5);
        expect(set.restAfterSeconds, 0);
        await _chooseFormat(tester, 'Series convencionales');
        await _save(tester);
        expect(input!.blocks.single.exercises.first.sets.first.targetValue, 7);
        expect(
          input!.blocks.single.exercises.first.sets.first.targetLoadKg,
          24,
        );
        expect(
          input!.blocks.single.exercises.first.sets.first.restAfterSeconds,
          45,
        );
        expect(input!.blocks.single.exercises.first.sets.last.targetValue, 12);
      },
    );
  }

  for (final duration in [true, false]) {
    testWidgets(
      'AMRAP no interpreta ${duration ? 'segundos' : 'metros'} como repeticiones y conserva ambos objetivos',
      (tester) async {
        CreatePersonalWorkoutInput? input;
        final original = _withItems([
          WorkoutItem(
            id: 'measured',
            exerciseId: 'base',
            exerciseName: 'Ejercicio de partida',
            sets: [
              WorkoutSet(
                id: 'measured-set',
                order: 0,
                targetDurationSeconds: duration ? 45 : null,
                targetDistanceMeters: duration ? null : 200,
                targetRir: 2.5,
                restAfterSeconds: 90,
              ),
            ],
          ),
        ]);
        await tester.pumpWidget(
          _app(
            original: original,
            save: (value) async {
              input = value;
              return 'saved';
            },
            saved: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        await _chooseFormat(tester, 'AMRAP · máximas vueltas');
        final fields = tester.widget<StrengthSetFields>(
          find.byType(StrengthSetFields).first,
        );
        expect(fields.targetType, WorkoutTargetType.repetitions);
        expect(fields.targetText, isEmpty);
        expect(fields.rirText, isEmpty);
        await _save(tester);
        expect(input, isNull);
        await _setField(
          tester,
          find.widgetWithText(TextFormField, 'Cantidad').first,
          '12',
        );
        await _save(tester);
        expect(
          input!.blocks.single.exercises.single.sets.single.targetType,
          WorkoutTargetType.repetitions,
        );
        expect(
          input!.blocks.single.exercises.single.sets.single.targetValue,
          12,
        );
        expect(
          input!.blocks.single.exercises.single.sets.single.targetRir,
          isNull,
        );
        await _chooseFormat(tester, 'Series convencionales');
        await _save(tester);
        expect(
          input!.blocks.single.exercises.single.sets.single.targetValue,
          duration ? 45 : 200,
        );
        expect(
          input!.blocks.single.exercises.single.sets.single.targetType,
          duration ? WorkoutTargetType.duration : WorkoutTargetType.distance,
        );
        await _chooseFormat(tester, 'AMRAP · máximas vueltas');
        expect(
          tester
              .widget<StrengthSetFields>(find.byType(StrengthSetFields).first)
              .targetText,
          '12',
        );
      },
    );
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
