import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum WorkoutLibraryStatus { initial, loading, ready, failure }

class WorkoutLibraryState extends Equatable {
  const WorkoutLibraryState({
    this.status = WorkoutLibraryStatus.initial,
    this.workouts = const [],
    this.personalWorkouts = const [],
    this.busyTemplateId,
    this.errorMessage,
  });

  final WorkoutLibraryStatus status;
  final List<WorkoutTemplateSummary> workouts;
  final List<WorkoutTemplateSummary> personalWorkouts;
  final String? busyTemplateId;
  final String? errorMessage;

  WorkoutLibraryState copyWith({
    WorkoutLibraryStatus? status,
    List<WorkoutTemplateSummary>? workouts,
    List<WorkoutTemplateSummary>? personalWorkouts,
    String? busyTemplateId,
    bool clearBusyTemplate = false,
    String? errorMessage,
    bool clearError = false,
  }) => WorkoutLibraryState(
    status: status ?? this.status,
    workouts: workouts ?? this.workouts,
    personalWorkouts: personalWorkouts ?? this.personalWorkouts,
    busyTemplateId: clearBusyTemplate
        ? null
        : busyTemplateId ?? this.busyTemplateId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    workouts,
    personalWorkouts,
    busyTemplateId,
    errorMessage,
  ];
}
