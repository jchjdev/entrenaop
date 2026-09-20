import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';

class GetStarterWorkoutUseCase {
  const GetStarterWorkoutUseCase(this._repository);

  static const starterTemplateId = '10000000-0000-4000-8000-000000000001';

  final WorkoutRepository _repository;

  Future<WorkoutTemplate?> call() =>
      _repository.getTemplateById(starterTemplateId);
}
