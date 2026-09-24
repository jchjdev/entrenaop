import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:workout_core/exercise_image.dart';

abstract class ExerciseRemoteDataSource {
  Future<List<ExerciseModel>> getExercises();
  Future<List<ExerciseModel>> getExercisesByMuscleGroup(String muscleGroup);
  Future<ExerciseModel?> getExerciseById(String id);

  //escritura
  Future<ExerciseModel> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  });
  Future<void> updateExercise(ExerciseModel exercise);
  Future<void> deleteExercise(String id);
}
