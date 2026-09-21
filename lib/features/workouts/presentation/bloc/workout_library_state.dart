import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum WorkoutLibraryStatus { initial, loading, ready, failure }

class WorkoutLibraryState extends Equatable {
  const WorkoutLibraryState({
    this.status = WorkoutLibraryStatus.initial,
    this.workouts = const [],
    this.errorMessage,
  });

  final WorkoutLibraryStatus status;
  final List<WorkoutTemplateSummary> workouts;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, workouts, errorMessage];
}
