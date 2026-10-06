import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/library/presentation/library_search.dart';

class ExerciseLibraryFilter {
  const ExerciseLibraryFilter({
    this.query = '',
    this.muscle,
    this.type,
    this.equipment,
    this.difficulty,
  });
  final String query;
  final String? muscle;
  final String? type;
  final String? equipment;
  final String? difficulty;

  bool matches(ExerciseEntity exercise) =>
      (muscle == null ||
          exercise.muscleGroups.any((v) => librarySearchText(v) == muscle)) &&
      (type == null || librarySearchText(exercise.exerciseType) == type) &&
      (equipment == null ||
          exercise.equipment.any((v) => librarySearchText(v) == equipment)) &&
      (difficulty == null ||
          librarySearchText(exercise.difficulty) == difficulty) &&
      matchesLibrarySearch(query, [
        exercise.name,
        exercise.description ?? '',
        ...exercise.muscleGroups,
        ...exercise.equipment,
        libraryOptionLabel(exercise.exerciseType),
      ]);
}
