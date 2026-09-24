import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';

void main() {
  testWidgets('crea y edita mediante el mismo formulario', (tester) async {
    ExerciseDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseForm(
            title: 'Editar ejercicio',
            supportingText: 'Contexto propio del cliente.',
            submitLabel: 'Guardar',
            autofocusName: false,
            initialDraft: const ExerciseDraft(
              name: 'Sentadilla',
              muscleGroups: ['piernas'],
              equipment: [],
              difficulty: 'inicial',
              exerciseType: 'repeticiones',
            ),
            onSubmit: (value) => submitted = value.draft,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('exercise-name')),
      '  Sentadilla goblet  ',
    );
    final save = find.text('Guardar');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();

    expect(submitted?.name, 'Sentadilla goblet');
    expect(submitted?.muscleGroups, ['piernas']);
  });
}
