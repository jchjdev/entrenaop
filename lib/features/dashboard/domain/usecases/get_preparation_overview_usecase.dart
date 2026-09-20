import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';

class GetPreparationOverviewUseCase {
  const GetPreparationOverviewUseCase({
    required PhysicalAssessmentRepository assessmentRepository,
    required TrainingPreferencesRepository preferencesRepository,
  }) : _assessmentRepository = assessmentRepository,
       _preferencesRepository = preferencesRepository;

  final PhysicalAssessmentRepository _assessmentRepository;
  final TrainingPreferencesRepository _preferencesRepository;

  Future<PreparationOverview> call() async {
    // Ambas lecturas son independientes, por lo que empiezan a la vez.
    final assessmentsFuture = _assessmentRepository.getHistory();
    final preferencesFuture = _preferencesRepository.get();

    return PreparationOverview(
      assessments: await assessmentsFuture,
      preferences: await preferencesFuture,
    );
  }
}
