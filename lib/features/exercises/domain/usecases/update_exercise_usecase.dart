// update_exercise_usecase.dart
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_core/exercise_draft.dart';

class UpdateExerciseUseCase {
  final ExerciseRepository repository;
  UpdateExerciseUseCase(this.repository);

  Future<void> call(
    ExerciseEntity exercise, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    if (exercise.origin != ExerciseOrigin.user ||
        exercise.isPublic ||
        exercise.createdBy == null) {
      throw const FormatException(
        'Solo puedes editar ejercicios personales privados.',
      );
    }
    final draft = ExerciseDraftValidator.normalizeAndValidate(
      ExerciseDraft(
        name: exercise.name,
        description: exercise.description,
        videoUrl: exercise.videoUrl,
        muscleGroups: exercise.muscleGroups,
        equipment: exercise.equipment,
        difficulty: exercise.difficulty,
        exerciseType: exercise.exerciseType,
      ),
    );
    return repository.updateExercise(
      ExerciseEntity(
        id: exercise.id,
        name: draft.name,
        description: draft.description,
        videoUrl: draft.videoUrl,
        muscleGroups: draft.muscleGroups,
        equipment: draft.equipment,
        difficulty: draft.difficulty,
        exerciseType: draft.exerciseType,
        thumbnailUrl: exercise.thumbnailUrl,
        origin: exercise.origin,
        isPublic: exercise.isPublic,
        createdBy: exercise.createdBy,
      ),
      image: image,
      removeImage: removeImage,
    );
  }
}
