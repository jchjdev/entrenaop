import 'dart:async';

import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Workouts extends Fake implements WorkoutRepository {
  Completer<String>? pending;
  int starts = 0;
  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => _workout;
  @override
  Future<String> startExecution(String id) async {
    starts++;
    return pending?.future ?? Future.value('execution');
  }
}

class _Exercises extends Fake implements ExerciseRepository {
  _Exercises(this.fetch);
  final Future<ExerciseEntity?> Function(String) fetch;
  final calls = <String>[];
  @override
  Future<ExerciseEntity?> getExerciseById(String id) {
    calls.add(id);
    return fetch(id);
  }
}

const _workout = WorkoutTemplate(
  id: 'template',
  name: 'Sesión',
  description: null,
  estimatedDurationMinutes: null,
  version: 1,
  blocks: [
    WorkoutBlock(
      id: 'block',
      name: 'Fuerza',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'one',
          exerciseId: 'photo',
          exerciseName: 'Con foto',
          sets: [],
        ),
        WorkoutItem(
          id: 'two',
          exerciseId: 'photo',
          exerciseName: 'Repetido',
          sets: [],
        ),
        WorkoutItem(
          id: 'three',
          exerciseId: 'plain',
          exerciseName: 'Sin foto',
          sets: [],
        ),
      ],
    ),
  ],
);

ExerciseEntity _photo(String url) => ExerciseEntity(
  id: 'photo',
  name: 'Ejercicio',
  thumbnailUrl: url,
  muscleGroups: const [],
  equipment: const [],
  difficulty: 'beginner',
  exerciseType: 'repetitions',
  isPublic: true,
  origin: ExerciseOrigin.system,
);

WorkoutPreviewCubit _cubit(_Workouts workouts, _Exercises exercises) =>
    WorkoutPreviewCubit(
      templateId: 'template',
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workouts),
      startExecution: StartWorkoutExecutionUseCase(workouts),
      getExercise: GetExerciseByIdUseCase(exercises),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'no espera las fotos para iniciar y consulta una vez cada ejercicio',
    () async {
      final photo = Completer<ExerciseEntity?>();
      final exercises = _Exercises(
        (id) async => id == 'photo' ? photo.future : null,
      );
      final workouts = _Workouts();
      final cubit = _cubit(workouts, exercises);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, WorkoutPreviewStatus.ready);
      expect(exercises.calls, ['photo', 'plain']);
      await cubit.start();
      expect(workouts.starts, 1);
      expect(cubit.state.executionId, 'execution');
      photo.complete(_photo('https://example.com/photo.png'));
      await _settle();
      expect(cubit.state.exerciseThumbnails, {
        'photo': 'https://example.com/photo.png',
      });
      expect(cubit.state.executionId, 'execution');
    },
  );

  test(
    'foto fallida no impide empezar y el inicio ocupado no se duplica',
    () async {
      final exercises = _Exercises((_) async => throw StateError('Sin imagen'));
      final workouts = _Workouts()..pending = Completer<String>();
      final cubit = _cubit(workouts, exercises);
      addTearDown(cubit.close);
      await cubit.load();
      await _settle();
      expect(cubit.state.status, WorkoutPreviewStatus.ready);
      final starting = cubit.start();
      await cubit.start();
      expect(workouts.starts, 1);
      workouts.pending!.complete('execution');
      await starting;
      expect(cubit.state.exerciseThumbnails, isEmpty);
      expect(cubit.state.executionId, 'execution');
    },
  );

  test(
    'las fotos tardías conservan el error y permiten reintentar el inicio',
    () async {
      final photo = Completer<ExerciseEntity?>();
      final exercises = _Exercises(
        (id) async => id == 'photo' ? photo.future : null,
      );
      final workouts = _Workouts()..pending = Completer<String>();
      final cubit = _cubit(workouts, exercises);
      addTearDown(cubit.close);
      await cubit.load();
      final starting = cubit.start();
      workouts.pending!.completeError(
        StateError('Sin conexión'),
        StackTrace.empty,
      );
      await starting;
      photo.complete(_photo('https://example.com/photo.png'));
      await _settle();
      expect(cubit.state.status, WorkoutPreviewStatus.failure);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.exerciseThumbnails, isNotEmpty);
      workouts.pending = null;
      await cubit.start();
      expect(cubit.state.executionId, 'execution');
      expect(cubit.state.exerciseThumbnails, isNotEmpty);
    },
  );

  test('recargar descarta respuestas antiguas y cerrar evita publicaciones tardías', () async {
    final old = Completer<ExerciseEntity?>();
    var reads = 0;
    final exercises = _Exercises((id) async {
      if (id == 'plain') return null;
      return ++reads == 1 ? old.future : _photo('https://example.com/new.png');
    });
    final cubit = _cubit(_Workouts(), exercises);
    await cubit.load();
    await cubit.load();
    await _settle();
    expect(
      cubit.state.exerciseThumbnails['photo'],
      'https://example.com/new.png',
    );
    old.complete(_photo('https://example.com/old.png'));
    await _settle();
    expect(
      cubit.state.exerciseThumbnails['photo'],
      'https://example.com/new.png',
    );
    await cubit.close();
  });

  test(
    'cerrar no publica una foto pendiente sobre una pantalla descartada',
    () async {
      final photo = Completer<ExerciseEntity?>();
      final cubit = _cubit(
        _Workouts(),
        _Exercises((id) async => id == 'photo' ? photo.future : null),
      );
      await cubit.load();
      await cubit.close();
      photo.complete(_photo('https://example.com/photo.png'));
      await _settle();
      expect(cubit.state.exerciseThumbnails, isEmpty);
    },
  );
}
