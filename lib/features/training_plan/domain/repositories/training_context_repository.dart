import '../entities/training_context.dart';

abstract interface class TrainingContextRepository {
  Future<TrainingContextSettings> load();
  Future<void> save(TrainingContext context);
}
