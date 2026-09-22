import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:entrenaop/features/workouts/presentation/pages/running_workout_editor_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carga una sesión existente y guarda una revisión', () async {
    final workoutRepository = _WorkoutRepository();
    final draftStore = _DraftStore()
      ..draft = WorkoutEditorDraftSnapshot(
        input: _input,
        savedAt: DateTime(2026, 9, 21),
      );
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: draftStore,
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
    expect(draftStore.draft, isNull);
  });

  test('añade un ejercicio propio al catálogo del editor', () async {
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    final created = await cubit.createExercise(
      const PersonalExerciseDraft(
        name: 'Press francés',
        muscleGroups: ['tríceps'],
        equipment: ['mancuerna'],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
      ),
    );

    expect(created.name, 'Press francés');
    expect(cubit.state.exercises.map((item) => item.name), [
      'Dominadas',
      'Press francés',
    ]);
  });

  testWidgets('permite configurar formatos y bloques en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: _DraftStore(),
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

  testWidgets('agrupa series de carrera y estima su duración por ritmo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final draftStore = _DraftStore();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: draftStore,
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
      runningEditor: true,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const RunningWorkoutEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Repetir último'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir último'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Tramo 1 × 4'), findsOneWidget);
    expect(find.text('1 bloque · 4/40 tramos'), findsOneWidget);

    final paceFrom = find.widgetWithText(TextFormField, 'Desde (min/km)');
    final paceTo = find.widgetWithText(TextFormField, 'Hasta (min/km)');
    await tester.ensureVisible(paceFrom);
    await tester.enterText(paceFrom, '4:00');
    await tester.enterText(paceTo, '4:30');
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('16 min–18 min'), findsOneWidget);
    expect(
      draftStore.draft?.input.blocks.single.exercises.single.sets,
      hasLength(4),
    );
    expect(draftStore.draft?.input.estimatedDurationMinutes, 17);
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
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: _DraftStore(),
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

  testWidgets('busca y crea un ejercicio propio desde el editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
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

    final addExercise = find.text('Añadir ejercicio al bloque');
    await tester.ensureVisible(addExercise);
    await tester.pumpAndSettle();
    await tester.tap(addExercise);
    await tester.pumpAndSettle();

    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('EntrenaOP'), findsOneWidget);
    expect(find.text('Míos'), findsOneWidget);
    await tester.tap(find.text('Crear ejercicio propio'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-name')),
      'Press francés',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-muscles')),
      'tríceps',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('personal-exercise-name')),
          )
          .controller
          ?.text,
      'Press francés',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('personal-exercise-muscles')),
          )
          .controller
          ?.text,
      'tríceps',
    );
    final createAndAdd = find.text('Crear y añadir');
    await tester.ensureVisible(createAndAdd);
    await tester.pumpAndSettle();
    await tester.tap(createAndAdd);
    await tester.pumpAndSettle();

    expect(
      cubit.state.exercises.map((item) => item.name),
      contains('Press francés'),
    );
    expect(find.text('Press francés'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recupera y vuelve a guardar automáticamente un borrador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final draftStore = _DraftStore()
      ..draft = WorkoutEditorDraftSnapshot(
        savedAt: DateTime(2026, 9, 21, 20, 30),
        input: const CreatePersonalWorkoutInput(
          name: 'Borrador recuperado',
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
                      targetValue: 8,
                      restAfterSeconds: 90,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: draftStore,
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
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
    await tester.pumpAndSettle();

    expect(find.text('Borrador encontrado'), findsOneWidget);
    await tester.tap(find.text('Recuperar'));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const ValueKey('workout-name'));
    expect(
      tester.widget<TextFormField>(nameField).controller?.text,
      'Borrador recuperado',
    );

    await tester.enterText(nameField, 'Borrador actualizado');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(draftStore.draft?.input.name, 'Borrador actualizado');
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
  Future<ExerciseEntity> createExercise(PersonalExerciseDraft exercise) async =>
      ExerciseEntity(
        id: 'exercise-personal',
        name: exercise.name,
        description: exercise.description,
        videoUrl: exercise.videoUrl,
        muscleGroups: exercise.muscleGroups,
        equipment: exercise.equipment,
        difficulty: exercise.difficulty,
        exerciseType: exercise.exerciseType,
        isPublic: false,
        createdBy: 'user-id',
        origin: ExerciseOrigin.user,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DraftStore implements WorkoutEditorDraftStore {
  WorkoutEditorDraftSnapshot? draft;

  @override
  Future<void> clear(String draftId) async => draft = null;

  @override
  Future<WorkoutEditorDraftSnapshot?> read(String draftId) async => draft;

  @override
  Future<void> write(
    String draftId,
    WorkoutEditorDraftSnapshot snapshot,
  ) async => draft = snapshot;
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
