import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:workout_core/workout_draft_validator.dart';

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
    validateWorkoutDraft(input);
    return _repository.createPersonalTemplate(input);
  }
}

class RevisePersonalWorkoutUseCase {
  const RevisePersonalWorkoutUseCase(this._repository);

  final WorkoutRepository _repository;

  Future<String> call(String templateId, CreatePersonalWorkoutInput input) {
    validateWorkoutDraft(input);
    return _repository.revisePersonalTemplate(templateId, input);
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
