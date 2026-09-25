import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:workout_core/exercise_image.dart';

abstract class ExerciseRepository {
  // Define the methods and properties for the ExerciseRepository

  //lectura
  Future<List<ExerciseEntity>> getExercises();
  Future<List<ExerciseEntity>> getExercisesByMuscleGroup(String muscleGroup);
  Future<ExerciseEntity?> getExerciseById(String id);

  //escritura
  Future<ExerciseEntity> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  });
  Future<void> updateExercise(ExerciseEntity exercise);
  Future<void> deleteExercise(String id);
}
