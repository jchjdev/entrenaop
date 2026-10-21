import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_controller.dart';

import 'exercise_preferences_controller_test.dart' show PreferenceSource;

import '../../../test/helpers/performance_visual_review.dart';

const catalog = [
  WorkoutEditorExercise(
    id: 'a',
    name: 'Extensión de glúteos',
    muscleGroups: ['Glúteos'],
    equipment: ['Polea'],
  ),
  WorkoutEditorExercise(
    id: 'b',
    name: 'Puente',
    muscleGroups: ['Gluteos'],
    equipment: ['Banda'],
  ),
  WorkoutEditorExercise(
    id: 'c',
    name: 'Remo',
    muscleGroups: ['Espalda'],
    equipment: ['Polea'],
  ),
];

Widget app({
  double scale = 1,
  ExercisePreferencesController? preferences,
  void Function(WorkoutEditorExercise)? selected,
}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(
      key: const ValueKey('review-boundary'),
      child: child!,
    ),
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ExerciseSearchList<WorkoutEditorExercise>(
        exercises: catalog,
        idOf: (e) => e.id,
        preferences: preferences,
        nameOf: (e) => e.name,
        searchTermsOf: (e) => [e.name, ...e.muscleGroups, ...e.equipment],
        muscleGroupsOf: (e) => e.muscleGroups,
        equipmentOf: (e) => e.equipment,
        thumbnailOf: (_) => null,
        onSelected: selected ?? (_) {},
      ),
    ),
  ),
);

void main() {
  setUpAll(() => loadReviewFont(always: true));
  testWidgets(
    'búsqueda por palabras sin tildes y filtros combinados usan el catálogo recibido',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gluteos polea');
      await tester.pumpAndSettle();
      expect(find.text('Extensión de glúteos'), findsOneWidget);
      expect(find.text('Puente'), findsNothing);
      expect(find.text('Remo'), findsNothing);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mostrar filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Glúteos').last);
      await tester.pumpAndSettle();
      expect(find.text('Remo'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banda').last);
      await tester.pumpAndSettle();
      expect(find.text('Puente'), findsOneWidget);
      expect(find.text('Extensión de glúteos'), findsNothing);
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      expect(find.text('Remo'), findsOneWidget);
    },
  );
  testWidgets('filtros utilizables a 320 px con texto doble', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(scale: 2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no existe');
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay ejercicios'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capturePerformanceWidget(tester, 'editor-exercise-filter-320-2x');
  });

  testWidgets('favoritos y recientes se intersectan con catálogo autorizado', (
    tester,
  ) async {
    final source = PreferenceSource();
    source.entries.addAll({
      'a': ExercisePreferenceEntry(
        exerciseId: 'a',
        favorite: true,
        favoriteRevision: 1,
        lastSelectedAt: DateTime.utc(2026, 10, 20),
      ),
      'b': ExercisePreferenceEntry(
        exerciseId: 'b',
        favorite: false,
        favoriteRevision: 0,
        lastSelectedAt: DateTime.utc(2026, 10, 21),
      ),
      'private-foreign': ExercisePreferenceEntry(
        exerciseId: 'private-foreign',
        favorite: true,
        favoriteRevision: 1,
        lastSelectedAt: DateTime.utc(2026, 10, 22),
      ),
    });
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(preferences: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver todos, favoritos o recientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.text('Extensión de glúteos'), findsOneWidget);
    expect(find.text('Puente'), findsNothing);
    expect(find.textContaining('private-foreign'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no coincide');
    await tester.pumpAndSettle();
    expect(find.text('Extensión de glúteos'), findsNothing);
    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ver todos, favoritos o recientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recientes').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Puente')).dy,
      lessThan(tester.getTopLeft(find.text('Extensión de glúteos')).dy),
    );
    expect(find.text('Remo'), findsNothing);
    expect(source.selections, isEmpty);
  });

  testWidgets('estrella guarda preferencia sin seleccionar ni registrar uso', (
    tester,
  ) async {
    final source = PreferenceSource();
    final controller = ExercisePreferencesController(source);
    addTearDown(controller.dispose);
    var selections = 0;
    await tester.pumpWidget(
      app(preferences: controller, selected: (_) => selections++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir a favoritos: Puente'));
    await tester.pumpAndSettle();
    expect(source.entries['b']!.favorite, isTrue);
    expect(selections, 0);
    expect(source.selections, isEmpty);
    expect(find.byTooltip('Quitar de favoritos: Puente'), findsOneWidget);
    await tester.tap(find.text('Puente'));
    expect(selections, 1);
    // El editor acepta la posición y registra uso; la lista no lo duplica.
    expect(source.selections, isEmpty);
  });

  testWidgets(
    'cambiar puerto de cuenta retira favoritos y búsqueda anteriores',
    (tester) async {
      final first = PreferenceSource();
      first.entries['a'] = const ExercisePreferenceEntry(
        exerciseId: 'a',
        favorite: true,
        favoriteRevision: 1,
      );
      final a = ExercisePreferencesController(first);
      final b = ExercisePreferencesController(PreferenceSource());
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(app(preferences: a));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gluteos');
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(preferences: b));
      await tester.pumpAndSettle();
      expect(find.text('Remo'), findsOneWidget);
      expect(
        find.byTooltip('Añadir a favoritos: Extensión de glúteos'),
        findsOneWidget,
      );
    },
  );

  testWidgets('preferencias y reintento utilizables a 320 px con texto doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ExercisePreferencesController(
      PreferenceSource()..failRead = true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(scale: 2, preferences: controller));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capturePerformanceWidget(tester, 'exercise-preferences-320-2x');
  });
}
