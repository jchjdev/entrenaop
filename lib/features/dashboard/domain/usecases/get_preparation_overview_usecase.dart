import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';

class GetPreparationOverviewUseCase {
  const GetPreparationOverviewUseCase({
    required PhysicalAssessmentRepository assessmentRepository,
    required TrainingPreferencesRepository preferencesRepository,
    required PreparationGoalRepository goalRepository,
    required WorkoutScheduleRepository scheduleRepository,
    DateTime Function()? now,
  }) : _assessmentRepository = assessmentRepository,
       _preferencesRepository = preferencesRepository,
       _goalRepository = goalRepository,
       _scheduleRepository = scheduleRepository,
       _now = now ?? DateTime.now;

  final PhysicalAssessmentRepository _assessmentRepository;
  final TrainingPreferencesRepository _preferencesRepository;
  final PreparationGoalRepository _goalRepository;
  final WorkoutScheduleRepository _scheduleRepository;
  final DateTime Function() _now;

  Future<PreparationOverview> call() async {
    // Ambas lecturas son independientes, por lo que empiezan a la vez.
    final assessmentsFuture = _assessmentRepository.getHistory();
    final preferencesFuture = _preferencesRepository.get();
    final goalsFuture = _goalRepository.getActiveGoals();
    final weekStart = _startOfWeek(_now());
    final scheduleFuture = _scheduleRepository.getRange(
      weekStart,
      weekStart.add(const Duration(days: 6)),
    );

    return PreparationOverview(
      assessments: await assessmentsFuture,
      preferences: await preferencesFuture,
      goals: await goalsFuture,
      weekStart: weekStart,
      weeklyWorkouts: await scheduleFuture,
    );
  }
}

DateTime _startOfWeek(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}
