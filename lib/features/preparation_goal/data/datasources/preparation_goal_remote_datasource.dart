import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';

abstract class PreparationGoalRemoteDataSource {
  Future<PreparationGoal?> getActive();

  Future<PreparationGoal> save(PreparationGoal goal);
}
