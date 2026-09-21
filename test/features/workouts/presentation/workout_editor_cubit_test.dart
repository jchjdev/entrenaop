import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  testWidgets('permite configurar formatos y bloques en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();
    final formatSelector = find.byType(
      DropdownButtonFormField<WorkoutBlockFormat>,
    );
    await tester.ensureVisible(formatSelector);
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superserie').last);
    await tester.pumpAndSettle();

    expect(find.text('Rondas'), findsOneWidget);
    expect(find.textContaining('exactamente dos ejercicios'), findsOneWidget);

    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tabata · 8 × 20/10').last);
    await tester.pumpAndSettle();

    expect(
      find.text('8 rondas · 20 s de trabajo · 10 s de recuperación'),
      findsOneWidget,
    );
    expect(find.textContaining('El tiempo es cerrado'), findsOneWidget);

    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('EMOM · cada minuto').last);
    await tester.pumpAndSettle();

    expect(find.text('Vueltas'), findsOneWidget);
    expect(find.textContaining('minutos con un ejercicio'), findsOneWidget);
    expect(
      find.textContaining('Cada ejercicio ocupa un minuto'),
      findsOneWidget,
    );

    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMRAP · máximas vueltas').last);
    await tester.pumpAndSettle();

    expect(find.text('Límite de tiempo'), findsOneWidget);
    expect(find.textContaining('vueltas completas'), findsOneWidget);

    final addBlock = find.byKey(const ValueKey('add-workout-block'));
    await tester.ensureVisible(addBlock);
    await tester.pumpAndSettle();
    await tester.tap(addBlock);
    await tester.pump();

    expect(find.text('Bloque 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una superserie guía A1 y A2 y permite repetir catálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();
    final formatSelector = find.byType(
      DropdownButtonFormField<WorkoutBlockFormat>,
    );
    await tester.ensureVisible(formatSelector);
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superserie').last);
    await tester.pumpAndSettle();

    expect(find.text('Pendiente de elegir'), findsNWidgets(2));
    await tester.tap(find.text('Elegir ejercicio A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dominadas').last);
    await tester.pumpAndSettle();

    expect(find.text('Elegir ejercicio A2'), findsOneWidget);
    await tester.ensureVisible(find.text('Elegir ejercicio A2'));
    await tester.tap(find.text('Elegir ejercicio A2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dominadas').last);
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsWidgets);
    expect(find.text('A2'), findsWidgets);
    expect(find.text('Superserie completa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _input = CreatePersonalWorkoutInput(
  name: 'Mi sesión revisada',
  estimatedDurationMinutes: 30,
  blocks: [
    WorkoutBlockDraft(
      name: 'Principal',
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
