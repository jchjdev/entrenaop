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
    _validatePersonalWorkout(input);
    return _repository.createPersonalTemplate(input);
  }
}

class RevisePersonalWorkoutUseCase {
  const RevisePersonalWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<String> call(String templateId, CreatePersonalWorkoutInput input) {
    _validatePersonalWorkout(input);
    return _repository.revisePersonalTemplate(templateId, input);
  }
}

void _validatePersonalWorkout(CreatePersonalWorkoutInput input) {
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
  if (input.blocks.isEmpty || input.blocks.length > 10) {
    throw const FormatException('Añade entre 1 y 10 bloques.');
  }
  var exerciseCount = 0;
  for (final block in input.blocks) {
    if (block.name.trim().isEmpty || block.name.trim().length > 60) {
      throw const FormatException(
        'Cada bloque necesita un nombre de hasta 60 caracteres.',
      );
    }
    if (block.format != WorkoutBlockFormat.straightSets &&
        block.format != WorkoutBlockFormat.superset &&
        block.format != WorkoutBlockFormat.circuit) {
      throw const FormatException(
        'Este formato de bloque todavía no está disponible.',
      );
    }
    if (block.exercises.isEmpty || block.exercises.length > 20) {
      throw const FormatException(
        'Cada bloque debe contener entre 1 y 20 ejercicios.',
      );
    }
    if (block.format == WorkoutBlockFormat.superset &&
        block.exercises.length != 2) {
      throw const FormatException(
        'Una superserie debe contener exactamente dos ejercicios.',
      );
    }
    if (block.format == WorkoutBlockFormat.circuit &&
        block.exercises.length < 2) {
      throw const FormatException(
        'Un circuito debe contener al menos dos ejercicios.',
      );
    }
    if (block.format == WorkoutBlockFormat.straightSets && block.rounds != 1) {
      throw const FormatException(
        'Los bloques convencionales no utilizan rondas.',
      );
    }
    if (block.rounds < 1 || block.rounds > 20) {
      throw const FormatException('Las rondas deben estar entre 1 y 20.');
    }
    if (block.restAfterSeconds < 0 || block.restAfterSeconds > 3600) {
      throw const FormatException(
        'El descanso entre rondas debe estar entre 0 y 3600 segundos.',
      );
    }
    exerciseCount += block.exercises.length;
    final exerciseIds = block.exercises.map((item) => item.exerciseId).toSet();
    if (exerciseIds.length != block.exercises.length) {
      throw const FormatException(
        'No repitas el mismo ejercicio dentro de un bloque.',
      );
    }
    for (final exercise in block.exercises) {
      if (exercise.sets.isEmpty || exercise.sets.length > 20) {
        throw const FormatException(
          'Cada ejercicio debe tener entre 1 y 20 series.',
        );
      }
      if (block.format != WorkoutBlockFormat.straightSets &&
          exercise.sets.length != block.rounds) {
        throw const FormatException(
          'Cada ejercicio debe tener una serie por ronda.',
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
  }
  if (exerciseCount > 40) {
    throw const FormatException(
      'Una sesión no puede superar 40 ejercicios en total.',
    );
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
