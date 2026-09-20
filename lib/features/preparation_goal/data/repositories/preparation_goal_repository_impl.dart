import 'package:entrenaop/features/preparation_goal/data/datasources/preparation_goal_remote_datasource.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';

class PreparationGoalRepositoryImpl implements PreparationGoalRepository {
  const PreparationGoalRepositoryImpl({required this.remoteDataSource});

  final PreparationGoalRemoteDataSource remoteDataSource;

  @override
  Future<PreparationGoal?> getActive() => remoteDataSource.getActive();

  @override
  Future<PreparationGoal> save(PreparationGoal goal) =>
      remoteDataSource.save(goal);
}
