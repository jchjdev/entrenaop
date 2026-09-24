import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';

class _FakeRepository implements AdminExerciseRepository {
  final exercises = <AdminCatalogExercise>[];
  ExerciseDraft? created;
  ExerciseDraft? updated;

  @override
  Future<void> createOfficial(ExerciseDraft draft) async {
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
  }

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => List.of(exercises);

  @override
  Future<void> updateOfficial(String id, ExerciseDraft draft) async {
    updated = draft;
  }
}

void main() {
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
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(repository.created?.name, 'Dominada estricta');
    expect(find.text('Dominada estricta'), findsOneWidget);
  });
}
