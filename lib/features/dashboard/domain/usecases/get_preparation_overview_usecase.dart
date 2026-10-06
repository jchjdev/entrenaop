import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';

class GetPreparationOverviewUseCase {
  const GetPreparationOverviewUseCase({
    required PhysicalAssessmentRepository assessmentRepository,
    required TrainingPreferencesRepository preferencesRepository,
    required PreparationGoalRepository goalRepository,
    required WorkoutScheduleRepository scheduleRepository,
    required Future<bool> Function(String goalId) hasFasAssessment,
    required Future<bool> Function(String goalId) hasProgramAssessment,
    required Future<List<AdaptiveProgramProgress>> Function() refreshPrograms,
    Future<TrainingContext?> Function()? loadTrainingContext,
    DateTime Function()? now,
  }) : _assessmentRepository = assessmentRepository,
       _preferencesRepository = preferencesRepository,
       _goalRepository = goalRepository,
       _scheduleRepository = scheduleRepository,
       _hasFasAssessment = hasFasAssessment,
       _hasProgramAssessment = hasProgramAssessment,
       _refreshPrograms = refreshPrograms,
       _loadTrainingContext = loadTrainingContext,
       _now = now ?? DateTime.now;

  final PhysicalAssessmentRepository _assessmentRepository;
  final TrainingPreferencesRepository _preferencesRepository;
  final PreparationGoalRepository _goalRepository;
  final WorkoutScheduleRepository _scheduleRepository;
  final Future<bool> Function(String goalId) _hasFasAssessment;
  final Future<bool> Function(String goalId) _hasProgramAssessment;
  final DateTime Function() _now;
  final Future<List<AdaptiveProgramProgress>> Function() _refreshPrograms;
  final Future<TrainingContext?> Function()? _loadTrainingContext;

  Future<PreparationOverview> call() async {
    // La recuperación precede a la consulta: Inicio debe ver las sesiones nuevas.
    final programs = await _refreshPrograms();
    // La evaluación de Tropa solo se consulta tras resolver la preparación.
    final preferencesFuture = _preferencesRepository.get();
    final contextFuture = _loadTrainingContext?.call();
    final goalsFuture = _goalRepository.getActiveGoals();
    final weekStart = _startOfWeek(_now());
    final scheduleFuture = _scheduleRepository.getRange(
      weekStart,
      weekStart.add(const Duration(days: 6)),
    );

    final goals = await goalsFuture;
    final troopGoal = goals
        .where(
          (goal) =>
              goal.programId == PreparationProgramIds.armedForcesTroopEntry,
        )
        .firstOrNull;
    final assessments = troopGoal?.id == null
        ? <PhysicalAssessmentHistoryEntry>[]
        : await _assessmentRepository.getHistoryForGoal(troopGoal!.id!);
    final assessedGoalIds = <String>{};
    if (troopGoal?.id != null && assessments.isNotEmpty) {
      assessedGoalIds.add(troopGoal!.id!);
    }
    for (final goal in goals) {
      final goalId = goal.id;
      if (goalId == null) continue;
      if (goal.programId == PreparationProgramIds.fasPeriodicAssessment) {
        if (await _hasFasAssessment(goalId)) assessedGoalIds.add(goalId);
      } else if (goal.programId !=
              PreparationProgramIds.armedForcesTroopEntry &&
          await _hasProgramAssessment(goalId)) {
        assessedGoalIds.add(goalId);
      }
    }
    return PreparationOverview(
      programs: programs,
      assessments: assessments,
      preferences: await preferencesFuture,
      trainingContext: await contextFuture,
      goals: goals,
      weekStart: weekStart,
      weeklyWorkouts: await scheduleFuture,
      assessedGoalIds: assessedGoalIds,
    );
  }
}

DateTime _startOfWeek(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}
