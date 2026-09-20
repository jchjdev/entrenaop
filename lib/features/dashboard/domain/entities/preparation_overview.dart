import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:equatable/equatable.dart';

enum PreparationNextStep {
  physicalAssessment,
  trainingPreferences,
  professionalReview,
  awaitingValidatedPlan,
}

class PreparationOverview extends Equatable {
  const PreparationOverview({
    required this.assessments,
    required this.preferences,
  });

  final List<PhysicalAssessmentHistoryEntry> assessments;
  final TrainingPreferences? preferences;

  PhysicalAssessmentHistoryEntry? get latestAssessment =>
      assessments.isEmpty ? null : assessments.first;

  PreparationNextStep get nextStep {
    if (latestAssessment == null) {
      return PreparationNextStep.physicalAssessment;
    }
    if (preferences == null) {
      return PreparationNextStep.trainingPreferences;
    }
    if (preferences!.requiresProfessionalReview) {
      return PreparationNextStep.professionalReview;
    }
    return PreparationNextStep.awaitingValidatedPlan;
  }

  @override
  List<Object?> get props => [assessments, preferences];
}
