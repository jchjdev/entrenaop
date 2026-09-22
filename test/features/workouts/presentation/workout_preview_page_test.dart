import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => workout;

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
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
