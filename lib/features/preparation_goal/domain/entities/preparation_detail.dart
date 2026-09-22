import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:equatable/equatable.dart';

/// Lectura conjunta del objetivo y de los hechos que ya pueden contextualizarlo.
///
/// No contiene una prescripción ni decisiones deportivas: solo conecta una
/// preparación activa con su evaluación compatible y su agenda semanal.
class PreparationDetail extends Equatable {
  const PreparationDetail({
    required this.goal,
    required this.weekStart,
    required this.weekEnd,
    required this.weeklyWorkouts,
    this.latestAssessment,
  });

  final PreparationGoal goal;
  final DateTime weekStart;
  final DateTime weekEnd;
  final PhysicalAssessmentHistoryEntry? latestAssessment;
  final List<ScheduledWorkout> weeklyWorkouts;

  @override
  List<Object?> get props => [
    goal,
    weekStart,
    weekEnd,
    latestAssessment,
    weeklyWorkouts,
  ];
}
