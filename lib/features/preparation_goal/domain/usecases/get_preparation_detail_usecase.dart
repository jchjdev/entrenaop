import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';

class GetPreparationDetailUseCase {
  const GetPreparationDetailUseCase({
    required PreparationGoalRepository goalRepository,
    required PhysicalAssessmentRepository assessmentRepository,
    required WorkoutScheduleRepository scheduleRepository,
  }) : _goalRepository = goalRepository,
       _assessmentRepository = assessmentRepository,
       _scheduleRepository = scheduleRepository;

  final PreparationGoalRepository _goalRepository;
  final PhysicalAssessmentRepository _assessmentRepository;
  final WorkoutScheduleRepository _scheduleRepository;

  Future<PreparationDetail> call(
    String goalId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final goals = await _goalRepository.getActiveGoals();
    final goal = goals.where((item) => item.id == goalId).firstOrNull;
    if (goal == null) {
      throw StateError('La preparación activa no existe.');
    }

    final assessments = await _assessmentRepository.getHistory();
    final catalogVersion = goal.program.currentAssessmentCatalogVersion;
    final latestAssessment = catalogVersion == null
        ? null
        : assessments
              .where((entry) => entry.report.catalogVersion == catalogVersion)
              .firstOrNull;

    final schedule = await _scheduleRepository.getRange(weekStart, weekEnd);
    final related = schedule
        .where((item) => item.preparationGoalId == goalId)
        .toList(growable: false);

    return PreparationDetail(
      goal: goal,
      weekStart: weekStart,
      weekEnd: weekEnd,
      latestAssessment: latestAssessment,
      weeklyWorkouts: related,
    );
  }
}
