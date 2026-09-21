import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';

class CreateExerciseUseCase {
  final ExerciseRepository repository;

  CreateExerciseUseCase(this.repository);

  Future<ExerciseEntity> call(PersonalExerciseDraft draft) {
    final name = draft.name.trim();
    final description = draft.description?.trim();
    final videoUrl = draft.videoUrl?.trim();
    final muscleGroups = _normalizedTags(draft.muscleGroups);
    final equipment = _normalizedTags(draft.equipment);

    if (name.length < 2 || name.length > 80) {
      throw const FormatException(
        'El nombre debe tener entre 2 y 80 caracteres.',
      );
    }
    if ((description?.length ?? 0) > 500) {
      throw const FormatException(
        'La descripción no puede superar 500 caracteres.',
      );
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final uri = Uri.tryParse(videoUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException(
          'El vídeo debe usar una dirección HTTPS válida.',
        );
      }
    }
    if (muscleGroups.isEmpty || muscleGroups.length > 10) {
      throw const FormatException('Añade entre 1 y 10 grupos musculares.');
    }
    if (equipment.length > 10) {
      throw const FormatException('No puedes añadir más de 10 materiales.');
    }
    if (!const {
      'inicial',
      'intermedio',
      'avanzado',
    }.contains(draft.difficulty)) {
      throw const FormatException('La dificultad elegida no es válida.');
    }
    if (!const {'repeticiones', 'duración'}.contains(draft.exerciseType)) {
      throw const FormatException('El tipo de ejercicio elegido no es válido.');
    }

    return repository.createExercise(
      PersonalExerciseDraft(
        name: name,
        description: description == null || description.isEmpty
            ? null
            : description,
        videoUrl: videoUrl == null || videoUrl.isEmpty ? null : videoUrl,
        muscleGroups: muscleGroups,
        equipment: equipment,
        difficulty: draft.difficulty,
        exerciseType: draft.exerciseType,
      ),
    );
  }
}

List<String> _normalizedTags(List<String> values) => values
    .map((value) => value.trim().toLowerCase())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);
