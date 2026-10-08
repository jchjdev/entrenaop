import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';

void main() {
  for (final (difficulty, type) in [
    ('intermedio', 'duración'),
    ('avanzado', 'repeticiones'),
  ]) {
    testWidgets(
      'edita $difficulty/$type sin recortar los selectores a texto 2×',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ExerciseDraft? submitted;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 192,
                  child: ExerciseForm(
                    title: 'Editar ejercicio',
                    supportingText: 'Prueba del formulario compartido.',
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
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> select(String label, String text) async {
          final field = find.widgetWithText(
            DropdownButtonFormField<String>,
            label,
          );
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text).last);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: field, matching: find.text(text)).first,
          );
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
          painter.dispose();
        }

        await select(
          'Dificultad',
          difficulty == 'intermedio' ? 'Intermedio' : 'Avanzado',
        );
        await select(
          'Medición habitual',
          type == 'duración' ? 'Tiempo' : 'Repeticiones',
        );
        final save = find.text('Guardar');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(submitted?.difficulty, difficulty);
        expect(submitted?.exerciseType, type);
        expect(submitted?.name, 'Sentadilla');
        expect(submitted?.muscleGroups, ['piernas']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('avisa de cambios y deja de avisar al restaurar los campos', (
    tester,
  ) async {
    bool? dirty;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseForm(
            title: 'Nuevo',
            supportingText: 'Personal',
            submitLabel: 'Guardar',
            autofocusName: false,
            onSubmit: (_) {},
            onDirtyChanged: (value) => dirty = value,
          ),
        ),
      ),
    );
    final name = find.byKey(const ValueKey('exercise-name'));
    await tester.enterText(name, 'Flexiones');
    await tester.pump();
    expect(dirty, true);
    await tester.enterText(name, '');
    await tester.pump();
    expect(dirty, false);
  });
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
