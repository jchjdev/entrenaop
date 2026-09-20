import 'package:entrenaop/features/training_plan/data/datasources/training_preferences_remote_datasource.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';

class TrainingPreferencesRepositoryImpl
    implements TrainingPreferencesRepository {
  const TrainingPreferencesRepositoryImpl({required this.remoteDataSource});

  final TrainingPreferencesRemoteDataSource remoteDataSource;

  @override
  Future<TrainingPreferences?> get() => remoteDataSource.get();

  @override
  Future<void> save(TrainingPreferences preferences) =>
      remoteDataSource.save(preferences);
}
