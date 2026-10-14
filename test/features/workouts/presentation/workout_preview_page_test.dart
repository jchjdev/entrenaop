import 'dart:async';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  for (final view in [
    (390.0, 844.0, 1.0),
    (320.0, 480.0, 2.0),
    (1000.0, 800.0, 1.0),
  ]) {
    testWidgets('el botón permanece visible sin tapar el final: $view', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(view.$1, view.$2));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final long = WorkoutTemplate(
        id: 'long',
        name: 'Sesión extensa',
        description: null,
        estimatedDurationMinutes: 60,
        version: 1,
        blocks: List.filled(10, _circuitWorkout.blocks.first),
      );
      final repository = _WorkoutRepository(workout: long);
      final cubit = WorkoutPreviewCubit(
        templateId: long.id,
        getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
        startExecution: StartWorkoutExecutionUseCase(repository),
      );
      await cubit.load();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(view.$3)),
              child: child!,
            ),
            home: BlocProvider.value(
              value: cubit,
              child: const WorkoutPreviewPage(routeBase: '/preview'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('workout-preview-start'));
      final atTop = tester.getRect(start);
      expect(atTop.bottom, lessThanOrEqualTo(view.$2));
      await capturePerformanceWidget(
        tester,
        'preview_fixed_top_${view.$1}_${view.$3}',
      );
      final lastText = find.textContaining(
        'Comprueba la sesión antes de empezar',
      );
      await Scrollable.ensureVisible(tester.element(lastText), alignment: 1);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(start), atTop);
      expect(tester.getRect(lastText).bottom, lessThanOrEqualTo(atTop.top));
      await capturePerformanceWidget(
        tester,
        'preview_fixed_bottom_${view.$1}_${view.$3}',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'las fotos llegan sin duplicar navegación y una imagen fallida no rompe el listado',
    (tester) async {
      final photo = Completer<ExerciseEntity?>();
      final exercises = _PreviewExercises(photo);
      final repository = _WorkoutRepository();
      final cubit = WorkoutPreviewCubit(
        templateId: repository.workout.id,
        getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
        startExecution: StartWorkoutExecutionUseCase(repository),
        getExercise: GetExerciseByIdUseCase(exercises),
      );
      await cubit.load();
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/preview',
        routes: [
          GoRoute(
            path: '/preview',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const WorkoutPreviewPage(routeBase: '/preview'),
            ),
            routes: [
              GoRoute(
                path: 'active/:id',
                builder: (_, _) => const Scaffold(body: Text('Entrenando')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Entrenando'), findsOneWidget);
      photo.complete(
        const ExerciseEntity(
          id: 'push-ups',
          name: 'Flexiones',
          thumbnailUrl: 'https://example.com/missing.png',
          muscleGroups: [],
          equipment: [],
          difficulty: 'beginner',
          exerciseType: 'repetitions',
          isPublic: true,
          origin: ExerciseOrigin.system,
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
      router.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'workout-exercise-photo:https://example.com/missing.png',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Flexiones'), findsOneWidget);
      expect(find.text('Sentadillas'), findsOneWidget);
      expect(find.text('Empezar sesión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'el pie bloquea doble inicio y deja reintentar sin perder el listado',
    (tester) async {
      final repository = _WorkoutRepository()..pending = Completer<String>();
      final cubit = WorkoutPreviewCubit(
        templateId: repository.workout.id,
        getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
        startExecution: StartWorkoutExecutionUseCase(repository),
      );
      await cubit.load();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: BlocProvider.value(
            value: cubit,
            child: const WorkoutPreviewPage(routeBase: '/preview'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('workout-preview-start'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(repository.starts, 1);
      repository.pending!.completeError(
        StateError('Sin conexión'),
        StackTrace.empty,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(
        find.text('No se pudo preparar la sesión. Puedes volver a intentarlo.'),
        findsOneWidget,
      );
      expect(find.text('Flexiones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la vista previa explica un circuito antes de iniciarlo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _WorkoutRepository();
    final cubit = WorkoutPreviewCubit(
      templateId: repository.workout.id,
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      startExecution: StartWorkoutExecutionUseCase(repository),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutPreviewPage(routeBase: '/plan/workout/test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Circuito'), findsOneWidget);
    expect(
      find.text('2 rondas · 2 estaciones · 1:30 min entre rondas'),
      findsOneWidget,
    );
    expect(find.text('E1  Flexiones'), findsOneWidget);
    expect(
      find.text('2 rondas · 10 repeticiones · 15 s transición'),
      findsOneWidget,
    );
    expect(find.textContaining('sesión pública'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la vista previa conserva objetivos diferentes por serie', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _WorkoutRepository(workout: _variableWorkout);
    final cubit = WorkoutPreviewCubit(
      templateId: repository.workout.id,
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      startExecution: StartWorkoutExecutionUseCase(repository),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutPreviewPage(routeBase: '/plan/workout/test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Serie 1 · 8 repeticiones · 40 kg · RIR 3 · 1 min descanso'),
      findsOneWidget,
    );
    expect(
      find.text('Serie 2 · 6 repeticiones · 45 kg · RIR 2 · 1:30 min descanso'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la vista previa explica ritmo y recuperación de carrera', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _WorkoutRepository(workout: _runningWorkout);
    final cubit = WorkoutPreviewCubit(
      templateId: repository.workout.id,
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      startExecution: StartWorkoutExecutionUseCase(repository),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutPreviewPage(routeBase: '/plan/workout/test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carrera por tramos'), findsOneWidget);
    expect(find.text('2 tramos ordenados'), findsOneWidget);
    expect(
      find.text(
        'Tramo 1 · 400 m · 4:00–4:15/km · recuperación trotando · 200 m',
      ),
      findsOneWidget,
    );
    expect(find.text('Registrar resultado'), findsOneWidget);
    expect(
      find.text(
        'Registra después del entrenamiento el resultado real de cada tramo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Empezar sesión'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _WorkoutRepository extends Fake implements WorkoutRepository {
  _WorkoutRepository({WorkoutTemplate? workout})
    : workout = workout ?? _circuitWorkout;

  final WorkoutTemplate workout;
  Completer<String>? pending;
  int starts = 0;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => workout;

  @override
  Future<String> startExecution(String templateId) async {
    starts++;
    return pending?.future ?? Future.value('execution-1');
  }
}

class _PreviewExercises extends Fake implements ExerciseRepository {
  _PreviewExercises(this.photo);
  final Completer<ExerciseEntity?> photo;
  @override
  Future<ExerciseEntity?> getExerciseById(String id) async =>
      id == 'push-ups' ? photo.future : null;
}

const _circuitWorkout = WorkoutTemplate(
  id: 'workout-circuit',
  name: 'Circuito base',
  description: 'Dos estaciones de prueba',
  estimatedDurationMinutes: 20,
  version: 1,
  blocks: [
    WorkoutBlock(
      id: 'block-1',
      name: 'Trabajo principal',
      format: WorkoutBlockFormat.circuit,
      rounds: 2,
      restAfterSeconds: 90,
      items: [
        WorkoutItem(
          id: 'item-1',
          exerciseId: 'push-ups',
          exerciseName: 'Flexiones',
          sets: [
            WorkoutSet(
              id: 'set-1',
              order: 0,
              targetReps: 10,
              restAfterSeconds: 15,
            ),
            WorkoutSet(
              id: 'set-2',
              order: 1,
              targetReps: 10,
              restAfterSeconds: 15,
            ),
          ],
        ),
        WorkoutItem(
          id: 'item-2',
          exerciseId: 'squats',
          exerciseName: 'Sentadillas',
          sets: [
            WorkoutSet(
              id: 'set-3',
              order: 0,
              targetReps: 15,
              restAfterSeconds: 0,
            ),
            WorkoutSet(
              id: 'set-4',
              order: 1,
              targetReps: 15,
              restAfterSeconds: 0,
            ),
          ],
        ),
      ],
    ),
  ],
);

const _variableWorkout = WorkoutTemplate(
  id: 'workout-variable',
  name: 'Fuerza variable',
  description: null,
  estimatedDurationMinutes: 15,
  version: 1,
  blocks: [
    WorkoutBlock(
      id: 'block-1',
      name: 'Press',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'item-1',
          exerciseId: 'bench-press',
          exerciseName: 'Press banca',
          sets: [
            WorkoutSet(
              id: 'set-1',
              order: 0,
              targetReps: 8,
              targetLoadKg: 40,
              targetRir: 3,
              restAfterSeconds: 60,
            ),
            WorkoutSet(
              id: 'set-2',
              order: 1,
              targetReps: 6,
              targetLoadKg: 45,
              targetRir: 2,
              restAfterSeconds: 90,
            ),
          ],
        ),
      ],
    ),
  ],
);

const _runningWorkout = WorkoutTemplate(
  id: 'workout-running',
  name: 'Series de pista',
  description: null,
  estimatedDurationMinutes: 30,
  version: 1,
  blocks: [
    WorkoutBlock(
      id: 'block-running',
      name: 'Carrera',
      format: WorkoutBlockFormat.running,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'item-running',
          exerciseId: runningExerciseId,
          exerciseName: 'Carrera',
          sets: [
            WorkoutSet(
              id: 'segment-1',
              order: 0,
              targetDistanceMeters: 400,
              targetPaceMinSecondsPerKm: 240,
              targetPaceMaxSecondsPerKm: 255,
              recoveryType: RunningRecoveryType.jogging,
              recoveryDistanceMeters: 200,
              restAfterSeconds: 0,
            ),
            WorkoutSet(
              id: 'segment-2',
              order: 1,
              targetDistanceMeters: 800,
              restAfterSeconds: 0,
            ),
          ],
        ),
      ],
    ),
  ],
);
