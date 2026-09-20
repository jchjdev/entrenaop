import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';

abstract class TrainingPreferencesRepository {
  Future<TrainingPreferences?> get();

  Future<void> save(TrainingPreferences preferences);
}
