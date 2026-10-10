import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_creator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:go_router/go_router.dart';

class _ExerciseRepository implements ExerciseRepository {
  PersonalExerciseDraft? created;
  bool denyCreation = false;

  @override
  Future<ExerciseEntity> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  }) async {
    if (denyCreation) throw ProAccessDenied.fromDetails('free_exercise_limit')!;
    created = exercise;
    return ExerciseEntity(
      id: 'exercise-id',
      name: exercise.name,
      description: exercise.description,
      videoUrl: exercise.videoUrl,
      muscleGroups: exercise.muscleGroups,
      equipment: exercise.equipment,
      difficulty: exercise.difficulty,
      exerciseType: exercise.exerciseType,
      isPublic: false,
      origin: ExerciseOrigin.user,
      createdBy: 'user-id',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'rechazar el noveno ejercicio invita a Pro y conserva nombre y material',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ExerciseRepository()..denyCreation = true;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PersonalExerciseCreatorPage(
              createExercise: CreateExerciseUseCase(repository),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(
        find.byKey(const ValueKey('personal-exercise-name')),
        'Remo propio',
      );
      await tester.enterText(
        find.byKey(const ValueKey('personal-exercise-muscles')),
        'espalda',
      );
      await tester.ensureVisible(find.text('Guardar ejercicio'));
      await tester.tap(find.text('Guardar ejercicio'));
      await tester.pumpAndSettle();
      expect(find.text('Ver Pro'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('personal-exercise-name')),
            )
            .controller
            ?.text,
        'Remo propio',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('personal-exercise-muscles')),
            )
            .controller
            ?.text,
        'espalda',
      );
      expect(repository.created, isNull);
    },
  );
  testWidgets('crea un ejercicio personal sin iniciar una sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ExerciseRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PersonalExerciseCreatorPage(
          createExercise: CreateExerciseUseCase(repository),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-name')),
      'Remo unilateral',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-muscles')),
      'espalda',
    );
    final save = find.text('Guardar ejercicio');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.created?.name, 'Remo unilateral');
    expect(repository.created?.muscleGroups, ['espalda']);
    expect(find.textContaining('se ha guardado'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('personal-exercise-name')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });
}
