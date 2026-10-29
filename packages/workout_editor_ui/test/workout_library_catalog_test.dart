import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';

void main() {
  testWidgets(
    'la biblioteca lateral muestra foto y filtra origen sin abandonar la receta',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProfessionalWorkspaceScope(
            desktop: true,
            child: WorkoutEditorPage(
              title: 'Sesión',
              heading: 'Receta',
              instructions: 'Planificar',
              saveLabel: 'Guardar',
              originalTemplate: const WorkoutTemplate(
                id: 'draft',
                name: 'Mi sesión',
              description: null,
              estimatedDurationMinutes: 30,
              version: 1,
                blocks: [
                  WorkoutBlock(
                    id: 'block',
                    name: 'Fuerza',
                    format: WorkoutBlockFormat.straightSets,
                    rounds: 1,
                    restAfterSeconds: 0,
                    items: [],
                  ),
                ],
              ),
              loadExercises: () async => const [
                WorkoutEditorExercise(
                  id: 'official',
                  name: 'Dominada oficial',
                  catalogScope: 'EntrenaOP',
                  thumbnailUrl: 'https://fixture.example.com/official.jpg',
                ),
                WorkoutEditorExercise(
                  id: 'own',
                  name: 'Dominada propia',
                  catalogScope: 'Míos',
                  thumbnailUrl: 'https://fixture.example.com/private.jpg',
                ),
              ],
              onSave: (_) async => 'saved',
              onSaved: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final library = find.byType(
        ProfessionalLibraryPane<WorkoutEditorExercise>,
      );
      expect(library, findsOneWidget);
      expect(
        find.descendant(of: library, matching: find.byType(ExerciseThumbnail)),
        findsNWidgets(2),
      );
      await tester.tap(
        find.descendant(
          of: library,
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Míos').last);
      await tester.pumpAndSettle();
      expect(find.text('Dominada propia'), findsOneWidget);
      expect(find.text('Dominada oficial'), findsNothing);
      expect(find.text('Mi sesión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
