import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:equatable/equatable.dart';

/// Lectura conjunta del objetivo y de los hechos que ya pueden contextualizarlo.
///
/// No contiene una prescripción ni decisiones deportivas: solo conecta una
/// preparación activa con las marcas propias que ya se consultan y su agenda.
class PreparationDetail extends Equatable {
  const PreparationDetail({
    required this.goal,
    required this.weekStart,
    required this.weekEnd,
    required this.weeklyWorkouts,
    this.latestRunningTest,
    this.latestTroopAssessment,
    this.runningReferenceCandidates = const [],
  });

  final PreparationGoal goal;
  final DateTime weekStart;
  final DateTime weekEnd;
  final RunningTestResult? latestRunningTest;
  final PhysicalAssessmentHistoryEntry? latestTroopAssessment;
  final List<RunningReferenceCandidate> runningReferenceCandidates;
  final List<ScheduledWorkout> weeklyWorkouts;

  @override
  List<Object?> get props => [
    goal,
    weekStart,
    weekEnd,
    latestRunningTest,
    latestTroopAssessment,
    runningReferenceCandidates,
    weeklyWorkouts,
  ];
}
