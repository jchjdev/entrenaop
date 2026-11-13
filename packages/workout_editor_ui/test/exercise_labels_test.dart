import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_catalog_labels.dart';
import 'package:workout_editor_ui/exercise_collection_selection.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';

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
      expect(preferences.labels('Sentadillas'), ['Técnica']);
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
    'respuesta perdida conserva operación, revisión y texto en reintento',
    (tester) async {
      final source = LabelsSource()..loseLabelResponse = true;
      final preferences = ExercisePreferencesController(source);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(catalog(preferences));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Etiquetas: Dominadas'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Etiquetas separadas por comas'),
        'Oposición, Inicio',
      );
      await tester.tap(find.text('Guardar etiquetas'));
      await tester.pumpAndSettle();
      expect(source.writes, hasLength(1));
      await tester.tap(find.text('Reintentar mismo envío'));
      await tester.pumpAndSettle();
      expect(source.writes, hasLength(2));
      expect(source.writes[0].$1, source.writes[1].$1);
      expect(source.writes[0].$2, source.writes[1].$2);
      expect(source.writes[0].$3, source.writes[1].$3);
      expect(source.writes[0].$4, source.writes[1].$4);
      expect(find.text('Mis etiquetas · Dominadas'), findsNothing);
      expect(preferences.labels('Dominadas'), ['Oposición', 'Inicio']);
    },
  );

  testWidgets('fallo de lectura no permite guardar etiquetas vacías', (
    tester,
  ) async {
    final preferences = ExercisePreferencesController(
      LabelsSource()..failLabels = true,
    );
    addTearDown(preferences.dispose);
    await tester.pumpWidget(catalog(preferences));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etiquetas: Dominadas'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar etiquetas'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
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
