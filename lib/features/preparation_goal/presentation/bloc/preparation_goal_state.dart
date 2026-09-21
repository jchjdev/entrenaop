import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:equatable/equatable.dart';

enum PreparationGoalStatus { initial, loading, ready, saving, saved, failure }

class PreparationGoalState extends Equatable {
  const PreparationGoalState({
    this.status = PreparationGoalStatus.initial,
    this.goals = const [],
    this.programs = const [],
    this.errorMessage,
  });

  final PreparationGoalStatus status;
  final List<PreparationGoal> goals;
  final List<PreparationProgram> programs;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, goals, programs, errorMessage];
}
