import 'package:entrenaop/features/library/presentation/library_search.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

enum LibrarySessionType { strength, running }

enum LibrarySessionDuration { short, medium, long }

class WorkoutLibraryFilter {
  const WorkoutLibraryFilter({this.query = '', this.type, this.duration});
  final String query;
  final LibrarySessionType? type;
  final LibrarySessionDuration? duration;

  bool matches(WorkoutTemplateSummary workout) {
    if (type != null &&
        workout.isRunning != (type == LibrarySessionType.running)) {
      return false;
    }
    if (duration != null) {
      final minutes = workout.estimatedDurationMinutes;
      if (minutes == null) return false;
      final fits = switch (duration!) {
        LibrarySessionDuration.short => minutes < 30,
        LibrarySessionDuration.medium => minutes >= 30 && minutes <= 45,
        LibrarySessionDuration.long => minutes > 45,
      };
      if (!fits) return false;
    }
    return matchesLibrarySearch(query, [
      workout.name,
      workout.description ?? '',
    ]);
  }
}
