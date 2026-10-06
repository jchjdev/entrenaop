import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';

class GetPreparationDetailUseCase {
  const GetPreparationDetailUseCase({
    required PreparationGoalRepository goalRepository,
    required Future<List<RunningTestResult>> Function(String goalId)
    loadRunningTests,
    required Future<List<PhysicalAssessmentHistoryEntry>> Function(
      String goalId,
    )
    loadTroopAssessments,
    required Future<List<RunningReferenceCandidate>> Function(String goalId)
    loadRunningReferenceCandidates,
    required WorkoutScheduleRepository scheduleRepository,
  }) : _goalRepository = goalRepository,
       _loadRunningTests = loadRunningTests,
       _loadTroopAssessments = loadTroopAssessments,
       _loadRunningReferenceCandidates = loadRunningReferenceCandidates,
       _scheduleRepository = scheduleRepository;

  final PreparationGoalRepository _goalRepository;
  final Future<List<RunningTestResult>> Function(String goalId)
  _loadRunningTests;
  final Future<List<PhysicalAssessmentHistoryEntry>> Function(String goalId)
  _loadTroopAssessments;
  final Future<List<RunningReferenceCandidate>> Function(String goalId)
  _loadRunningReferenceCandidates;
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

    final latestRunningTest =
        goal.programId == PreparationProgramIds.armedForcesTroopEntry
        ? (await _loadRunningTests(goalId)).firstOrNull
        : null;
    final latestTroopAssessment =
        goal.programId == PreparationProgramIds.armedForcesTroopEntry
        ? (await _loadTroopAssessments(goalId)).firstOrNull
        : null;

    final schedule = await _scheduleRepository.getRange(weekStart, weekEnd);
    final runningReferenceCandidates = await _loadRunningReferenceCandidates(
      goalId,
    );
    final related = schedule
        .where((item) => item.preparationGoalId == goalId)
        .toList(growable: false);

    return PreparationDetail(
      goal: goal,
      weekStart: weekStart,
      weekEnd: weekEnd,
      latestRunningTest: latestRunningTest,
      latestTroopAssessment: latestTroopAssessment,
      runningReferenceCandidates: runningReferenceCandidates,
      weeklyWorkouts: related,
    );
  }
}
