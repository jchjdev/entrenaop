import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';

class GetStarterWorkoutUseCase {
  const GetStarterWorkoutUseCase(this._repository);

  static const starterTemplateId = '10000000-0000-4000-8000-000000000001';

  final WorkoutRepository _repository;

  Future<WorkoutTemplate?> call() =>
      _repository.getTemplateById(starterTemplateId);
}

class GetWorkoutTemplateUseCase {
  const GetWorkoutTemplateUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<WorkoutTemplate?> call(String templateId) =>
      _repository.getTemplateById(templateId);
}

class GetPublicWorkoutsUseCase {
  const GetPublicWorkoutsUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<List<WorkoutTemplateSummary>> call() =>
      _repository.getPublicTemplates();
}

class GetPersonalWorkoutsUseCase {
  const GetPersonalWorkoutsUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<List<WorkoutTemplateSummary>> call() =>
      _repository.getPersonalTemplates();
}

class CreatePersonalWorkoutUseCase {
  const CreatePersonalWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<String> call(CreatePersonalWorkoutInput input) {
    final name = input.name.trim();
    if (name.length < 3 || name.length > 80) {
      throw const FormatException(
        'El nombre debe tener entre 3 y 80 caracteres.',
      );
    }
    if ((input.description?.trim().length ?? 0) > 500) {
      throw const FormatException(
        'La descripción no puede superar 500 caracteres.',
      );
    }
    final duration = input.estimatedDurationMinutes;
    if (duration != null && (duration < 1 || duration > 600)) {
      throw const FormatException(
        'La duración debe estar entre 1 y 600 minutos.',
      );
    }
    if (input.exercises.isEmpty || input.exercises.length > 20) {
      throw const FormatException('Añade entre 1 y 20 ejercicios.');
    }
    final exerciseIds = input.exercises.map((item) => item.exerciseId).toSet();
    if (exerciseIds.length != input.exercises.length) {
      throw const FormatException(
        'No repitas el mismo ejercicio en la sesión.',
      );
    }
    for (final exercise in input.exercises) {
      if (exercise.sets.isEmpty || exercise.sets.length > 20) {
        throw const FormatException(
          'Cada ejercicio debe tener entre 1 y 20 series.',
        );
      }
      for (final set in exercise.sets) {
        if (set.targetValue <= 0) {
          throw const FormatException(
            'El objetivo de cada serie debe ser mayor que cero.',
          );
        }
        if (set.restAfterSeconds < 0 || set.restAfterSeconds > 3600) {
          throw const FormatException(
            'El descanso debe estar entre 0 y 3600 segundos.',
          );
        }
        if ((set.targetLoadKg ?? 0) < 0 ||
            (set.targetRir != null &&
                (set.targetRir! < 0 || set.targetRir! > 10))) {
          throw const FormatException(
            'Revisa la carga y el RIR de las series.',
          );
        }
      }
    }
    return _repository.createPersonalTemplate(input);
  }
}

class DuplicatePersonalWorkoutUseCase {
  const DuplicatePersonalWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<String> call(String templateId) =>
      _repository.duplicatePersonalTemplate(templateId);
}

class ArchivePersonalWorkoutUseCase {
  const ArchivePersonalWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<void> call(String templateId) =>
      _repository.archivePersonalTemplate(templateId);
}
