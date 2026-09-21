import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carga una sesión existente y guarda una revisión', () async {
    final workoutRepository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
      templateId: 'template-v1',
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, WorkoutEditorStatus.ready);
    expect(cubit.state.originalTemplate?.version, 1);

    await cubit.save(_input);

    expect(cubit.state.status, WorkoutEditorStatus.saved);
    expect(cubit.state.createdTemplateId, 'template-v2');
    expect(workoutRepository.revisedTemplateId, 'template-v1');
  });
}

const _input = CreatePersonalWorkoutInput(
  name: 'Mi sesión revisada',
  estimatedDurationMinutes: 30,
  exercises: [
    WorkoutExerciseDraft(
      exerciseId: 'exercise-1',
      sets: [
        WorkoutSetDraft(
          targetType: WorkoutTargetType.repetitions,
          targetValue: 8,
          restAfterSeconds: 90,
        ),
      ],
    ),
  ],
);

class _ExerciseRepository implements ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async => const [
    ExerciseEntity(
      id: 'exercise-1',
      name: 'Dominadas',
      muscleGroups: ['espalda'],
      equipment: ['barra'],
      difficulty: 'media',
      exerciseType: 'repeticiones',
      isPublic: true,
      origin: ExerciseOrigin.system,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WorkoutRepository implements WorkoutRepository {
  String? revisedTemplateId;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async =>
      const WorkoutTemplate(
        id: 'template-v1',
        name: 'Mi sesión',
        description: 'Descripción',
        estimatedDurationMinutes: 30,
        version: 1,
        blocks: [
          WorkoutBlock(
            id: 'block-1',
            name: 'Sesión',
            format: WorkoutBlockFormat.straightSets,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'item-1',
                exerciseId: 'exercise-1',
                exerciseName: 'Dominadas',
                sets: [
                  WorkoutSet(
                    id: 'set-1',
                    order: 0,
                    targetReps: 6,
                    restAfterSeconds: 90,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async {
    revisedTemplateId = templateId;
    return 'template-v2';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
