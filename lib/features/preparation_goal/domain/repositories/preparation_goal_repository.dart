import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';

abstract class PreparationGoalRepository {
  Future<List<PreparationGoal>> getActiveGoals();

  Future<List<PreparationProgram>> getAvailablePrograms();

  Future<PreparationGoal> save(PreparationGoal goal);

  Future<void> archive(String goalId);
}
