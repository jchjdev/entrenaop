import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

abstract class WorkoutRepository {
  Future<WorkoutTemplate?> getTemplateById(String id);
}
