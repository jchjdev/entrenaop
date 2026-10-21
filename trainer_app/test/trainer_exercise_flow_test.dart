import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

class ExerciseFixture extends TrainerExerciseRepository {
  bool fail = false;
  int limit = 500;
  final saves =
      <
        ({
          String operation,
          ExerciseFormSubmission<ExerciseDraft> submission,
          TrainerExercise? previous,
        })
      >[];
  List<TrainerExercise> rows = [];
  @override
  Future<List<TrainerExercise>> list() async => rows;
  @override
  Future<TrainerExerciseUsage> usage() async => TrainerExerciseUsage.fromJson({
    'exercise_used': rows.length,
    'exercise_limit': limit,
    'image_used': 0,
    'image_limit': 1000,
  });
  @override
  Future<String> save(
    String operationId,
    ExerciseFormSubmission<ExerciseDraft> submission, {
    TrainerExercise? previous,
  }) async {
    saves.add((
      operation: operationId,
      submission: submission,
      previous: previous,
    ));
    if (fail) throw StateError('Conexión interrumpida');
    return 'saved';
  }
}

TrainerExercise entry(String id, {bool current = true}) =>
    TrainerExercise.fromJson({
      'id': id,
      'name': id,
      'version': 1,
      'current': current,
      'muscle_groups': ['espalda'],
      'equipment': ['barra'],
      'difficulty': 'inicial',
      'exercise_type': 'repeticiones',
    });

Future<void> open(WidgetTester tester, ExerciseFixture repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: TrainerExercisePage(
        repository: repository,
        access: FakeTrainerRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el catálogo muestra versiones vigentes y permite buscarlas', (
    tester,
  ) async {
    final repo = ExerciseFixture()
      ..rows = [
        entry('Dominada propia'),
        entry('Versión anterior', current: false),
        entry('Flexión propia'),
      ];
    await open(tester, repo);
    expect(find.text('Dominada propia'), findsOneWidget);
    expect(find.text('Versión anterior'), findsNothing);
    await tester.enterText(find.byType(TextField), 'dominada');
    await tester.pumpAndSettle();
    expect(find.text('Flexión propia'), findsNothing);
    expect(find.textContaining('3/500 ejercicios'), findsOneWidget);
  });

  testWidgets(
    'reutiliza ExerciseForm y reintenta el mismo envío sin duplicar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = ExerciseFixture()..fail = true;
      await open(tester, repo);
      await tester.tap(find.text('Crear ejercicio privado'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseForm), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-name')),
        'Dominada de ensayo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trainer-exercise-muscles')),
        'espalda',
      );
      await tester.ensureVisible(find.text('Crear ejercicio'));
      await tester.tap(find.text('Crear ejercicio'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar el mismo guardado'), findsOneWidget);
      expect(repo.saves, hasLength(1));
      repo.fail = false;
      await tester.tap(find.text('Reintentar el mismo guardado'));
      await tester.pumpAndSettle();
      expect(repo.saves, hasLength(2));
      expect(repo.saves[0].operation, repo.saves[1].operation);
      expect(
        identical(repo.saves[0].submission, repo.saves[1].submission),
        isTrue,
      );
      expect(find.byType(ExerciseForm), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el cupo agotado impide empezar otro ejercicio', (tester) async {
    final repo = ExerciseFixture()
      ..rows = [entry('Último ejercicio')]
      ..limit = 1;
    await open(tester, repo);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear ejercicio privado'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Último ejercicio'), findsOneWidget);
  });

  testWidgets('biblioteca y formulario caben en móvil con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: TrainerExercisePage(
          repository: ExerciseFixture(),
          access: FakeTrainerRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Crear ejercicio privado'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Crear ejercicio privado'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseForm), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
