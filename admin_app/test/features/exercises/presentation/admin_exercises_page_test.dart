import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_editor_ui/exercise_catalog_card.dart';
import 'package:workout_editor_ui/exercise_search_list.dart'
    show ExerciseThumbnail;

import '../../../../../packages/workout_editor_ui/test/exercise_labels_test.dart'
    show LabelsSource;

class _FakeRepository implements AdminExerciseRepository {
  final exercises = <AdminCatalogExercise>[];
  ExerciseDraft? created;
  ExerciseDraft? updated;
  bool failSave = false;

  @override
  Future<String> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) async {
    if (failSave) throw StateError('Sin conexión');
    created = draft;
    exercises.add(
      AdminCatalogExercise(
        id: 'new-id',
        name: draft.name,
        description: draft.description,
        videoUrl: draft.videoUrl,
        muscleGroups: draft.muscleGroups,
        equipment: draft.equipment,
        difficulty: draft.difficulty,
        exerciseType: draft.exerciseType,
      ),
    );
    return 'new-id';
  }

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => List.of(exercises);

  @override
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    updated = draft;
  }
}

void main() {
  testWidgets('ADMIN combina músculo y material con los nombres del catálogo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository()
      ..exercises.addAll([
        for (final (name, muscle, equipment) in [
          ('Elevación con barra', 'pantorrillas', 'barra'),
          ('Elevación con mancuerna', 'gemelos', 'mancuerna'),
          ('Remo con barra', 'espalda', 'barra'),
        ])
          AdminCatalogExercise(
            id: name,
            name: name,
            muscleGroups: [muscle],
            equipment: [equipment],
            difficulty: 'inicial',
            exerciseType: 'repeticiones',
          ),
      ]);
    await tester.pumpWidget(
      MaterialApp(home: AdminExercisesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Todos los músculos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gemelos').last);
    await tester.pumpAndSettle();
    expect(find.text('Elevación con barra'), findsOneWidget);
    expect(find.text('Elevación con mancuerna'), findsOneWidget);
    expect(find.text('Remo con barra'), findsNothing);

    await tester.tap(find.text('Todo el material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('barra').last);
    await tester.pumpAndSettle();
    expect(find.text('Elevación con barra'), findsOneWidget);
    expect(find.text('Elevación con mancuerna'), findsNothing);
  });

  testWidgets('ADMIN consulta las mismas colecciones privadas del editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final labels = LabelsSource();
    final repo = _FakeRepository()
      ..exercises.addAll([
        for (final name in ['Dominadas', 'Sentadillas'])
          AdminCatalogExercise(
            id: name,
            name: name,
            muscleGroups: const ['piernas'],
            equipment: const [],
            difficulty: 'inicial',
            exerciseType: 'repeticiones',
          ),
      ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminExercisesPage(repository: repo, preferences: labels),
      ),
    );
    await tester.pumpAndSettle();
    final cardTitle = find.text('Dominadas');
    final cardLabels = find.byTooltip('Etiquetas: Dominadas');
    final card = find.ancestor(
      of: cardTitle,
      matching: find.byType(ExerciseCatalogCard),
    );
    final thumbnail = find.descendant(
      of: card,
      matching: find.byType(ExerciseThumbnail),
    );
    final subtitle = find.descendant(of: card, matching: find.text('piernas'));
    final textCenter =
        (tester.getTopLeft(cardTitle).dy + tester.getBottomLeft(subtitle).dy) /
        2;
    expect(tester.getCenter(thumbnail).dy, closeTo(textCenter, 0.01));
    expect(
      tester.getRect(cardLabels).bottom,
      lessThanOrEqualTo(tester.getRect(cardTitle).top),
    );
    await tester.tap(find.text('Técnica (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Dominadas'), findsOneWidget);
    expect(find.text('Sentadillas'), findsNothing);
    expect(repo.updated, isNull);
    expect(repo.created, isNull);

    await tester.tap(find.text('Todos (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear colección o añadir a una existente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Marca los ejercicios que quieras añadir a la colección.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dominadas'));
    await tester.tap(find.text('Sentadillas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir a colección'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre de la colección'),
      'Oposición',
    );
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    expect(find.text('Oposición (2)'), findsOneWidget);
    expect(labels.writes.map((write) => write.$2), [
      ['Técnica', 'Oposición'],
      ['Oposición'],
    ]);
  });

  testWidgets('el enlace de calidad abre el editor existente sin guardar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository()
      ..exercises.add(
        const AdminCatalogExercise(
          id: 'quality-exercise',
          name: 'Puente de glúteos',
          description: 'Preparar apoyo',
          videoUrl: null,
          muscleGroups: ['glúteos'],
          equipment: [],
          difficulty: 'inicial',
          exerciseType: 'repeticiones',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminExercisesPage(
          repository: repository,
          initialExerciseId: 'quality-exercise',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar ejercicio oficial'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('admin-exercise-name')),
          )
          .controller!
          .text,
      'Puente de glúteos',
    );
    expect(repository.updated, isNull);
    expect(repository.created, isNull);
  });

  testWidgets('el panel crea un ejercicio con el formulario compartido', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminExercisesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo ejercicio'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Vídeo externo'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('admin-exercise-name')),
      'Dominada estricta',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-exercise-muscles')),
      'espalda',
    );
    final create = find.text('Crear ejercicio');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    repository.failSave = true;
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(repository.created, isNull);
    expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('admin-exercise-name')),
          )
          .controller!
          .text,
      'Dominada estricta',
    );
    repository.failSave = false;
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(repository.created?.name, 'Dominada estricta');
    expect(find.text('Dominada estricta'), findsOneWidget);
  });
}
