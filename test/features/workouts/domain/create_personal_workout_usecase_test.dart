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

  test('valida y envía una revisión sobre la plantilla original', () async {
    final revisedId = await RevisePersonalWorkoutUseCase(repository)(
      'template-v1',
      _validInput(),
    );

    expect(revisedId, 'template-revised');
    expect(repository.revisedTemplateId, 'template-v1');
    expect(repository.revised, _validInput());
  });

  test('rechaza ejercicios repetidos antes de llamar a Supabase', () async {
    final exercise = _validInput().blocks.single.exercises.single;
    final input = CreatePersonalWorkoutInput(
      name: 'Sesión repetida',
      blocks: [
        WorkoutBlockDraft(name: 'Principal', exercises: [exercise, exercise]),
      ],
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
    expect(repository.created, isNull);
  });

  test('rechaza objetivos vacíos o negativos', () async {
    const input = CreatePersonalWorkoutInput(
      name: 'Sesión inválida',
      blocks: [
        WorkoutBlockDraft(
          name: 'Principal',
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
        ),
      ],
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
  });

  test('permite reutilizar un ejercicio en bloques distintos', () async {
    final exercise = _validInput().blocks.single.exercises.single;
    final input = CreatePersonalWorkoutInput(
      name: 'Técnica y trabajo principal',
      blocks: [
        WorkoutBlockDraft(name: 'Técnica', exercises: [exercise]),
        WorkoutBlockDraft(name: 'Principal', exercises: [exercise]),
      ],
    );

    await useCase(input);

    expect(repository.created, input);
  });

  test('valida las rondas de una superserie', () async {
    final exercise = _validInput().blocks.single.exercises.single;
    final input = CreatePersonalWorkoutInput(
      name: 'Superserie incompleta',
      blocks: [
        WorkoutBlockDraft(
          name: 'Superserie',
          format: WorkoutBlockFormat.superset,
          rounds: 3,
          restAfterSeconds: 90,
          exercises: [exercise],
        ),
      ],
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
    expect(repository.created, isNull);
  });

  test('acepta intervalos de un ejercicio con una serie por vuelta', () async {
    final input = _timedInput(
      format: WorkoutBlockFormat.intervals,
      rounds: 4,
      workSeconds: 45,
      recoverySeconds: 30,
    );

    await useCase(input);

    expect(repository.created, input);
  });

  test('acepta el protocolo Tabata canónico', () async {
    final input = _timedInput(
      format: WorkoutBlockFormat.tabata,
      rounds: 8,
      workSeconds: 20,
      recoverySeconds: 10,
    );

    await useCase(input);

    expect(repository.created, input);
  });

  test('rechaza llamar Tabata a un protocolo distinto de 20/10', () async {
    final input = _timedInput(
      format: WorkoutBlockFormat.tabata,
      rounds: 8,
      workSeconds: 30,
      recoverySeconds: 10,
    );

    await expectLater(() => useCase(input), throwsA(isA<FormatException>()));
    expect(repository.created, isNull);
  });
}

CreatePersonalWorkoutInput _timedInput({
  required WorkoutBlockFormat format,
  required int rounds,
  required int workSeconds,
  required int recoverySeconds,
}) => CreatePersonalWorkoutInput(
  name: format == WorkoutBlockFormat.tabata
      ? 'Tabata personal'
      : 'Intervalos personales',
  blocks: [
    WorkoutBlockDraft(
      name: 'Trabajo por tiempo',
      format: format,
      rounds: rounds,
      restAfterSeconds: recoverySeconds,
      exercises: [
        WorkoutExerciseDraft(
          exerciseId: 'exercise-1',
          sets: List.generate(
            rounds,
            (_) => WorkoutSetDraft(
              targetType: WorkoutTargetType.duration,
              targetValue: workSeconds.toDouble(),
              restAfterSeconds: 0,
            ),
          ),
        ),
      ],
    ),
  ],
);

CreatePersonalWorkoutInput _validInput() => const CreatePersonalWorkoutInput(
  name: 'Fuerza personal',
  estimatedDurationMinutes: 35,
  blocks: [
    WorkoutBlockDraft(
      name: 'Principal',
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
    ),
  ],
);

class _Repository implements WorkoutRepository {
  CreatePersonalWorkoutInput? created;
  CreatePersonalWorkoutInput? revised;
  String? revisedTemplateId;

  @override
  Future<String> createPersonalTemplate(
    CreatePersonalWorkoutInput input,
  ) async {
    created = input;
    return 'template-created';
  }

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async {
    revisedTemplateId = templateId;
    revised = input;
    return 'template-revised';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
