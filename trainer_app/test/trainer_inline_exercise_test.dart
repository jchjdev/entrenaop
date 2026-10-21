import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/exercise_form.dart';

import 'trainer_exercise_flow_test.dart' show ExerciseFixture;
import 'trainer_workout_flow_test.dart'
    show WorkoutFixture, privateRecipe, press;

void main() {
  for (final cancel in [false, true]) {
    testWidgets(
      'ejercicio contextual privado ${cancel ? 'cancelado conserva' : 'confirmado sustituye'} la posición y conserva su pauta',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final workouts = WorkoutFixture();
        final exercises = ExerciseFixture()..fail = !cancel;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/edit'),
                  child: const Text('Editar'),
                ),
              ),
            ),
            GoRoute(
              path: '/edit',
              builder: (_, _) => TrainerWorkoutEditorPage(
                repository: workouts,
                templateId: privateRecipe.id,
                onCreateExercise: (context) =>
                    showTrainerExerciseEditor(context, exercises),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
        );
        await press(tester, 'Editar');
        await press(tester, 'Cambiar ejercicio · Dominadas');
        await press(tester, 'Crear ejercicio');
        expect(find.byType(ExerciseForm), findsOneWidget);
        if (cancel) {
          await press(tester, 'Cerrar');
        } else {
          await tester.enterText(
            find.byKey(const ValueKey('trainer-exercise-name')),
            'Dominada técnica privada',
          );
          await tester.enterText(
            find.byKey(const ValueKey('trainer-exercise-muscles')),
            'espalda',
          );
          await press(tester, 'Crear ejercicio');
          expect(find.text('Reintentar el mismo guardado'), findsOneWidget);
          expect(workouts.saved, isEmpty);
          exercises.fail = false;
          await press(tester, 'Reintentar el mismo guardado');
          expect(exercises.saves, hasLength(2));
          expect(
            exercises.saves.first.operation,
            exercises.saves.last.operation,
          );
          expect(
            find.text('Cambiar ejercicio · Dominada técnica privada'),
            findsOneWidget,
          );
        }
        expect(find.byType(ExerciseForm), findsNothing);
        await press(tester, 'Guardar nueva versión');
        final input = workouts.saved.single.input;
        final item = input.blocks.single.exercises.single;
        final set = item.sets.single;
        expect(input.name, privateRecipe.name);
        expect(item.exerciseId, cancel ? 'exercise' : 'saved');
        expect(
          (
            set.targetValue,
            set.targetLoadKg,
            set.targetRir,
            set.restAfterSeconds,
          ),
          (10.0, 5.0, 2.0, 90),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
