import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_catalog_labels.dart';
import 'package:workout_editor_ui/exercise_collection_selection.dart';
import 'package:workout_editor_ui/exercise_collections.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/manage_exercise_collection_dialog.dart';

import 'exercise_preferences_controller_test.dart' show PreferenceSource;

class LabelsSource extends PreferenceSource implements ExerciseCatalogLabels {
  List<String> labels = ['Técnica'];
  int revision = 1;
  bool failLabels = false, loseLabelResponse = false;
  final writes = <(String, List<String>, int, String)>[];
  final labelReceipts = <String, ExerciseLabelEntry>{};
  @override
  Future<List<ExerciseLabelEntry>> readLabels() async {
    if (failLabels) throw StateError('Sin red');
    return [
      ExerciseLabelEntry(
        exerciseId: 'Dominadas',
        labels: labels,
        revision: revision,
      ),
    ];
  }

  @override
  Future<ExerciseLabelEntry> setLabels(
    String id,
    List<String> labels, {
    required int expectedRevision,
    required String operationId,
  }) async {
    writes.add((id, List.of(labels), expectedRevision, operationId));
    if (labelReceipts[operationId] case final receipt?) return receipt;
    final entry = ExerciseLabelEntry(
      exerciseId: id,
      labels: labels,
      revision: ++revision,
    );
    this.labels = List.of(labels);
    labelReceipts[operationId] = entry;
    if (loseLabelResponse) {
      loseLabelResponse = false;
      throw StateError('Respuesta perdida');
    }
    return entry;
  }
}

Widget catalog(ExercisePreferencesController preferences) => MaterialApp(
  home: Scaffold(
    body: ExerciseSearchList<String>(
      exercises: const ['Dominadas', 'Sentadillas'],
      nameOf: (s) => s,
      searchTermsOf: (s) => [s],
      thumbnailOf: (_) => null,
      idOf: (s) => s,
      preferences: preferences,
      onSelected: (_) {},
    ),
  ),
);

void main() {
  testWidgets('renombra y elimina la agrupación también fuera de la pestaña', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _ManageLabelsSource();
    final preferences = ExercisePreferencesController(source);
    final selected = ValueNotifier<String?>(null);
    addTearDown(preferences.dispose);
    addTearDown(selected.dispose);
    await preferences.refreshLabels();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([preferences, selected]),
            builder: (context, _) => ExerciseCollections(
              memberships: [preferences.labels('Dominadas')],
              selected: selected.value,
              onChanged: (name) => selected.value = name,
              onManage: (name, action) =>
                  manageExerciseCollection(context, preferences, name, action),
            ),
          ),
        ),
      ),
    );
    final collection = find.widgetWithText(InputChip, 'Técnica (1)');
    final all = find.widgetWithText(ChoiceChip, 'Todos (1)');
    final menu = find.byTooltip('Opciones de la colección Técnica');
    expect(find.descendant(of: collection, matching: menu), findsOneWidget);
    expect(tester.getCenter(collection).dy, tester.getCenter(all).dy);
    expect(
      tester.getCenter(menu).dy,
      closeTo(tester.getCenter(collection).dy, 1),
    );
    await tester.tap(find.text('Técnica (1)'));
    await tester.pumpAndSettle();
    expect(selected.value, 'Técnica');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(selected.value, 'Técnica');
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'movilidad');
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ya existe una colección con ese nombre.'),
      findsOneWidget,
    );
    expect(source.writes, isEmpty);
    await tester.enterText(find.byType(TextField), 'Oposición');
    await tester.tap(find.text('Guardar nombre'));
    await tester.pumpAndSettle();
    expect(preferences.labels('Dominadas'), ['Oposición', 'Movilidad']);
    expect(preferences.labels('Remo'), ['Oposición']);

    await tester.tap(find.byTooltip('Opciones de la colección Oposición'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar colección'));
    await tester.pumpAndSettle();
    expect(find.text('«Oposición» · 2 ejercicios'), findsOneWidget);
    expect(source.writes, hasLength(2));
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar colección'));
    await tester.pumpAndSettle();
    expect(preferences.labels('Dominadas'), ['Movilidad']);
    expect(preferences.labels('Remo'), isEmpty);
    expect(find.text('Oposición (1)'), findsNothing);
  });

  testWidgets(
    'añade varios conservando etiquetas y reintenta solo pendientes',
    (tester) async {
      final source = _BatchLabelsSource();
      final preferences = ExercisePreferencesController(source);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => addExercisesToCollection(
                  context,
                  preferences,
                  selected: const {
                    'Dominadas': 'Dominadas',
                    'Sentadillas': 'Sentadillas',
                  },
                  catalogIds: const ['Dominadas', 'Sentadillas', 'Remo'],
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Técnica');
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cambios confirmados: 1 de 2'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar pendientes'));
      await tester.pumpAndSettle();
      expect(source.writes.map((write) => write.$1), [
        'Dominadas',
        'Sentadillas',
        'Sentadillas',
      ]);
      expect(source.writes[1].$4, source.writes[2].$4);
      expect(preferences.labels('Dominadas'), ['Técnica', 'Fuerza']);
      expect(preferences.labels('Sentadillas'), ['Movilidad', 'Técnica']);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('busca etiquetas privadas sin cambiar términos del catálogo', (
    tester,
  ) async {
    final preferences = ExercisePreferencesController(LabelsSource());
    addTearDown(preferences.dispose);
    await tester.pumpWidget(catalog(preferences));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tecnica');
    await tester.pumpAndSettle();
    expect(find.text('Dominadas'), findsOneWidget);
    expect(find.text('Sentadillas'), findsNothing);
    expect(find.text('Técnica'), findsOneWidget);
  });

  testWidgets(
    'marca varias colecciones y reintenta el mismo guardado si se pierde la respuesta',
    (tester) async {
      final source = _BatchLabelsSource()..loseLabelResponse = true;
      final preferences = ExercisePreferencesController(source);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(catalog(preferences));
      await tester.pumpAndSettle();
      final folder = find.byTooltip('Colecciones: Dominadas');
      expect(
        find.descendant(
          of: folder,
          matching: find.byIcon(Icons.folder_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(folder);
      await tester.pumpAndSettle();
      expect(find.text('Colecciones de Dominadas'), findsOneWidget);
      final assigned = find.widgetWithText(CheckboxListTile, 'Fuerza');
      expect(tester.widget<CheckboxListTile>(assigned).value, isTrue);
      await tester.tap(assigned);
      final existing = find.widgetWithText(CheckboxListTile, 'Movilidad');
      expect(tester.widget<CheckboxListTile>(existing).value, isFalse);
      await tester.tap(existing);
      await tester.tap(find.text('Nueva colección'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la colección'),
        'Oposición',
      );
      await tester.tap(find.text('Crear colección'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Oposición'),
            )
            .value,
        isTrue,
      );
      expect(source.writes, isEmpty);
      await tester.tap(find.text('Guardar colecciones'));
      await tester.pumpAndSettle();
      expect(source.writes, hasLength(1));
      await tester.tap(find.text('Reintentar mismo envío'));
      await tester.pumpAndSettle();
      expect(source.writes, hasLength(2));
      expect(source.writes[0].$1, source.writes[1].$1);
      expect(source.writes[0].$2, source.writes[1].$2);
      expect(source.writes[0].$3, source.writes[1].$3);
      expect(source.writes[0].$4, source.writes[1].$4);
      expect(find.text('Colecciones de Dominadas'), findsNothing);
      expect(preferences.labels('Dominadas'), [
        'técnica',
        'Movilidad',
        'Oposición',
      ]);
    },
  );

  testWidgets('permite reintentar la lectura antes de editar colecciones', (
    tester,
  ) async {
    final source = LabelsSource()..failLabels = true;
    final preferences = ExercisePreferencesController(source);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(catalog(preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Colecciones: Dominadas'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar colecciones'), findsNothing);
    source.failLabels = false;
    await tester.tap(find.text('Reintentar lectura de colecciones'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Técnica'),
          )
          .value,
      isTrue,
    );
  });
}

class _ManageLabelsSource extends LabelsSource {
  @override
  Future<List<ExerciseLabelEntry>> readLabels() async => [
    for (final (id, names) in [
      ('Dominadas', ['Técnica', 'Movilidad']),
      ('Remo', ['Técnica']),
    ])
      labelReceipts.values.lastWhere(
        (entry) => entry.exerciseId == id,
        orElse: () =>
            ExerciseLabelEntry(exerciseId: id, labels: names, revision: 1),
      ),
  ];
}

class _BatchLabelsSource extends LabelsSource {
  @override
  Future<List<ExerciseLabelEntry>> readLabels() async => [
    ExerciseLabelEntry(
      exerciseId: 'Dominadas',
      labels: ['técnica', 'Fuerza'],
      revision: 1,
    ),
    ExerciseLabelEntry(exerciseId: 'Remo', labels: ['Técnica'], revision: 1),
    ExerciseLabelEntry(
      exerciseId: 'Sentadillas',
      labels: ['Movilidad'],
      revision: 1,
    ),
  ];

  @override
  Future<ExerciseLabelEntry> setLabels(
    String id,
    List<String> labels, {
    required int expectedRevision,
    required String operationId,
  }) {
    if (id == 'Sentadillas' &&
        labelReceipts.isNotEmpty &&
        !labelReceipts.containsKey(operationId)) {
      loseLabelResponse = true;
    }
    return super.setLabels(
      id,
      labels,
      expectedRevision: expectedRevision,
      operationId: operationId,
    );
  }
}
