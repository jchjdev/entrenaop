import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/data/repositories/exercise_repository_impl.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercise = ExerciseEntity(
    id: 'exercise-id',
    name: 'Dominadas',
    muscleGroups: ['espalda'],
    equipment: ['barra'],
    difficulty: 'intermedio',
    exerciseType: 'repeticiones',
    isPublic: true,
    createdBy: 'coach-id',
  );

  group('ExerciseRepositoryImpl', () {
    test('convierte una entidad de dominio antes de crearla', () async {
      final dataSource = _FakeExerciseRemoteDataSource();
      final repository = ExerciseRepositoryImpl(remoteDataSource: dataSource);

      await repository.createExercise(exercise);

      expect(dataSource.created, isA<ExerciseModel>());
      expect(dataSource.created?.props, exercise.props);
    });

    test('convierte una entidad de dominio antes de actualizarla', () async {
      final dataSource = _FakeExerciseRemoteDataSource();
      final repository = ExerciseRepositoryImpl(remoteDataSource: dataSource);

      await repository.updateExercise(exercise);

      expect(dataSource.updated, isA<ExerciseModel>());
      expect(dataSource.updated?.props, exercise.props);
    });
  });
}

class _FakeExerciseRemoteDataSource implements ExerciseRemoteDataSource {
  ExerciseModel? created;
  ExerciseModel? updated;

  @override
  Future<void> createExercise(ExerciseModel exercise) async {
    created = exercise;
  }

  @override
  Future<void> updateExercise(ExerciseModel exercise) async {
    updated = exercise;
  }

  @override
  Future<void> deleteExercise(String id) async {}

  @override
  Future<ExerciseModel?> getExerciseById(String id) async => null;

  @override
  Future<List<ExerciseModel>> getExercises() async => [];

  @override
  Future<List<ExerciseModel>> getExercisesByMuscleGroup(
    String muscleGroup,
  ) async => [];
}
