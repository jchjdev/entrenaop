import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza y crea un ejercicio privado', () async {
    final repository = _ExerciseRepository();
    final useCase = CreateExerciseUseCase(repository);

    final created = await useCase(
      const PersonalExerciseDraft(
        name: '  Press francés  ',
        description: '  Controla la bajada.  ',
        videoUrl: 'https://example.com/video',
        muscleGroups: [' Tríceps ', 'tríceps'],
        equipment: [' Mancuerna '],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
      ),
    );

    expect(repository.received?.name, 'Press francés');
    expect(repository.received?.muscleGroups, ['tríceps']);
    expect(repository.received?.equipment, ['mancuerna']);
    expect(created.origin, ExerciseOrigin.user);
    expect(created.isPublic, isFalse);
  });

  test('rechaza un enlace de vídeo que no sea HTTPS', () {
    final useCase = CreateExerciseUseCase(_ExerciseRepository());

    expect(
      () => useCase(
        const PersonalExerciseDraft(
          name: 'Press francés',
          videoUrl: 'http://example.com/video',
          muscleGroups: ['tríceps'],
          equipment: ['mancuerna'],
          difficulty: 'intermedio',
          exerciseType: 'repeticiones',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _ExerciseRepository implements ExerciseRepository {
  PersonalExerciseDraft? received;

  @override
  Future<ExerciseEntity> createExercise(PersonalExerciseDraft exercise) async {
    received = exercise;
    return ExerciseEntity(
      id: 'created-id',
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
