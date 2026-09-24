import 'package:entrenaop/features/exercises/data/datasources/exercise_remote_datasource.dart';
import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:workout_core/exercise_image.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseRemoteDataSource remoteDataSource;

  ExerciseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ExerciseEntity> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  }) {
    return remoteDataSource.createExercise(exercise, image: image);
  }

  @override
  Future<void> deleteExercise(String id) async {
    return await remoteDataSource.deleteExercise(id);
  }

  @override
  Future<ExerciseEntity?> getExerciseById(String id) async {
    return await remoteDataSource.getExerciseById(id);
  }

  @override
  Future<List<ExerciseEntity>> getExercises() async {
    return await remoteDataSource.getExercises();
  }

  @override
  Future<List<ExerciseEntity>> getExercisesByMuscleGroup(
    String muscleGroup,
  ) async {
    return await remoteDataSource.getExercisesByMuscleGroup(muscleGroup);
  }

  @override
  Future<void> updateExercise(ExerciseEntity exercise) async {
    return remoteDataSource.updateExercise(ExerciseModel.fromEntity(exercise));
  }

  // Implement the methods and properties defined in ExerciseRepository
}
