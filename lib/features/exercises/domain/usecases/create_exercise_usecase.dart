import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';

class CreateExerciseUseCase {
  final ExerciseRepository repository;

  CreateExerciseUseCase(this.repository);

  Future<ExerciseEntity> call(
    PersonalExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) {
    return repository.createExercise(
      ExerciseDraftValidator.normalizeAndValidate(draft),
      image: image,
    );
  }
}
