import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Repository repository;
  late CreatePersonalWorkoutUseCase useCase;

  setUp(() {
    repository = _Repository();
    useCase = CreatePersonalWorkoutUseCase(repository);
  });

  test('acepta una sesión convencional válida', () async {
    final id = await useCase(_validInput());

    expect(id, 'template-created');
    expect(repository.created, _validInput());
  });

  test('rechaza ejercicios repetidos antes de llamar a Supabase', () async {
    final exercise = _validInput().exercises.single;
    final input = CreatePersonalWorkoutInput(
      name: 'Sesión repetida',
      exercises: [exercise, exercise],
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
    expect(repository.created, isNull);
  });

  test('rechaza objetivos vacíos o negativos', () async {
    const input = CreatePersonalWorkoutInput(
      name: 'Sesión inválida',
      exercises: [
        WorkoutExerciseDraft(
          exerciseId: 'exercise-1',
          sets: [
            WorkoutSetDraft(
              targetType: WorkoutTargetType.repetitions,
              targetValue: 0,
              restAfterSeconds: 60,
            ),
          ],
        ),
      ],
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
  });
}

CreatePersonalWorkoutInput _validInput() => const CreatePersonalWorkoutInput(
  name: 'Fuerza personal',
  estimatedDurationMinutes: 35,
  exercises: [
    WorkoutExerciseDraft(
      exerciseId: 'exercise-1',
      sets: [
        WorkoutSetDraft(
          targetType: WorkoutTargetType.repetitions,
          targetValue: 10,
          restAfterSeconds: 60,
          targetRir: 2,
        ),
      ],
    ),
  ],
);

class _Repository implements WorkoutRepository {
  CreatePersonalWorkoutInput? created;

  @override
  Future<String> createPersonalTemplate(
    CreatePersonalWorkoutInput input,
  ) async {
    created = input;
    return 'template-created';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
