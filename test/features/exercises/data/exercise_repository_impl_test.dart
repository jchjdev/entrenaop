import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/data/repositories/exercise_repository_impl.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_image.dart';

void main() {
  const exercise = PersonalExerciseDraft(
    name: 'Dominadas',
    muscleGroups: ['espalda'],
    equipment: ['barra'],
    difficulty: 'intermedio',
    exerciseType: 'repeticiones',
  );
  const existingExercise = ExerciseEntity(
    id: 'exercise-id',
    name: 'Dominadas',
    muscleGroups: ['espalda'],
    equipment: ['barra'],
    difficulty: 'intermedio',
    exerciseType: 'repeticiones',
    isPublic: false,
    origin: ExerciseOrigin.user,
    createdBy: 'user-id',
  );

  group('ExerciseRepositoryImpl', () {
    test('acepta ejercicios del sistema sin propietario personal', () {
      final model = ExerciseModel.fromJson({
        'id': 'system-exercise-id',
        'name': 'Plancha frontal',
        'description': null,
        'video_url': null,
        'thumbnail_url': null,
        'muscle_groups': ['core'],
        'equipment': ['peso corporal'],
        'difficulty': 'inicial',
        'exercise_type': 'duración',
        'is_public': true,
        'created_by': null,
        'origin': 'system',
      });

      expect(model.origin, ExerciseOrigin.system);
      expect(model.createdBy, isNull);
    });

    test('envía el borrador y devuelve el ejercicio creado', () async {
      final dataSource = _FakeExerciseRemoteDataSource();
      final repository = ExerciseRepositoryImpl(remoteDataSource: dataSource);

      final created = await repository.createExercise(exercise);

      expect(dataSource.created, exercise);
      expect(created.id, 'exercise-id');
    });

    test('convierte una entidad de dominio antes de actualizarla', () async {
      final dataSource = _FakeExerciseRemoteDataSource();
      final repository = ExerciseRepositoryImpl(remoteDataSource: dataSource);

      await repository.updateExercise(existingExercise);

      expect(dataSource.updated, isA<ExerciseModel>());
      expect(dataSource.updated?.props, existingExercise.props);
    });
  });
}

class _FakeExerciseRemoteDataSource implements ExerciseRemoteDataSource {
  PersonalExerciseDraft? created;
  ExerciseModel? updated;

  @override
  Future<ExerciseModel> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  }) async {
    created = exercise;
    return const ExerciseModel(
      id: 'exercise-id',
      name: 'Dominadas',
      muscleGroups: ['espalda'],
      equipment: ['barra'],
      difficulty: 'intermedio',
      exerciseType: 'repeticiones',
      isPublic: false,
      origin: ExerciseOrigin.user,
      createdBy: 'user-id',
    );
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
