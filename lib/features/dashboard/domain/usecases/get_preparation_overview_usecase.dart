import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';

class GetPreparationOverviewUseCase {
  const GetPreparationOverviewUseCase({
    required PhysicalAssessmentRepository assessmentRepository,
    required TrainingPreferencesRepository preferencesRepository,
    required PreparationGoalRepository goalRepository,
  }) : _assessmentRepository = assessmentRepository,
       _preferencesRepository = preferencesRepository,
       _goalRepository = goalRepository;

  final PhysicalAssessmentRepository _assessmentRepository;
  final TrainingPreferencesRepository _preferencesRepository;
  final PreparationGoalRepository _goalRepository;

  Future<PreparationOverview> call() async {
    // Ambas lecturas son independientes, por lo que empiezan a la vez.
    final assessmentsFuture = _assessmentRepository.getHistory();
    final preferencesFuture = _preferencesRepository.get();
    final goalsFuture = _goalRepository.getActiveGoals();

    return PreparationOverview(
      assessments: await assessmentsFuture,
      preferences: await preferencesFuture,
      goals: await goalsFuture,
    );
  }
}
