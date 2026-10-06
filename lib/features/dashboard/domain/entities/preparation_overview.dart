import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:equatable/equatable.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';

enum PreparationNextStep {
  preparationGoal,
  assessment,
  trainingPreferences,
  professionalReview,
  awaitingValidatedPlan,
  adaptiveProgram,
}

class PreparationOverview extends Equatable {
  const PreparationOverview({
    required this.assessments,
    required this.preferences,
    required this.goals,
    required this.weekStart,
    required this.weeklyWorkouts,
    this.assessedGoalIds = const {},
    this.programs = const [],
    this.trainingContext,
  });

  final List<PhysicalAssessmentHistoryEntry> assessments;
  final TrainingPreferences? preferences;
  final TrainingContext? trainingContext;
  final List<PreparationGoal> goals;
  final DateTime weekStart;
  final List<ScheduledWorkout> weeklyWorkouts;
  final Set<String> assessedGoalIds;
  final List<AdaptiveProgramProgress> programs;
  AdaptiveProgramProgress? get activeProgram =>
      programs.where((p) => p.needsReview).firstOrNull ??
      programs
          .where((p) => p.isStarted && !p.isPaused && p.status != 'complete')
          .firstOrNull ??
      programs.where((p) => p.isPaused).firstOrNull;

  PhysicalAssessmentHistoryEntry? get latestAssessment =>
      goals.any(
            (goal) =>
                goal.programId == PreparationProgramIds.armedForcesTroopEntry,
          ) &&
          assessments.isNotEmpty
      ? assessments.first
      : null;

  PreparationGoal? get goalNeedingAssessment => goals
      .where((goal) => goal.id != null && !assessedGoalIds.contains(goal.id))
      .firstOrNull;

  PreparationNextStep get nextStep {
    if (activeProgram != null) return PreparationNextStep.adaptiveProgram;
    if (goals.isEmpty) {
      return PreparationNextStep.preparationGoal;
    }
    if (goalNeedingAssessment != null) {
      return PreparationNextStep.assessment;
    }
    if (trainingContext case final current?) {
      if (!current.capacityConfirmed ||
          !current.availability.values.any((minutes) => minutes > 0)) {
        return PreparationNextStep.trainingPreferences;
      }
      return current.reportsPain
          ? PreparationNextStep.professionalReview
          : PreparationNextStep.awaitingValidatedPlan;
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
  List<Object?> get props => [
    assessments,
    preferences,
    trainingContext,
    goals,
    weekStart,
    weeklyWorkouts,
    assessedGoalIds,
    programs,
  ];
}
