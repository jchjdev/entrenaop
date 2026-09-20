import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:equatable/equatable.dart';

enum PreparationGoalStatus { initial, loading, ready, saving, saved, failure }

class PreparationGoalState extends Equatable {
  const PreparationGoalState({
    this.status = PreparationGoalStatus.initial,
    this.goal,
    this.errorMessage,
  });

  final PreparationGoalStatus status;
  final PreparationGoal? goal;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, goal, errorMessage];
}
