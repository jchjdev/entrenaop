import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/models/workout_template_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl({required this.remoteDataSource});

  final WorkoutRemoteDataSource remoteDataSource;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async {
    final json = await remoteDataSource.getTemplateById(id);
    return json == null ? null : WorkoutTemplateModel.fromJson(json);
  }
}
