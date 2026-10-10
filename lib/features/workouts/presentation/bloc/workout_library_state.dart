import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';

enum WorkoutLibraryStatus { initial, loading, ready, failure }

class WorkoutLibraryState extends Equatable {
  const WorkoutLibraryState({
    this.status = WorkoutLibraryStatus.initial,
    this.workouts = const [],
    this.personalWorkouts = const [],
    this.busyTemplateId,
    this.errorMessage,
    this.accessDenied,
  });

  final WorkoutLibraryStatus status;
  final List<WorkoutTemplateSummary> workouts;
  final List<WorkoutTemplateSummary> personalWorkouts;
  final String? busyTemplateId;
  final String? errorMessage;
  final ProAccessDenied? accessDenied;

  WorkoutLibraryState copyWith({
    WorkoutLibraryStatus? status,
    List<WorkoutTemplateSummary>? workouts,
    List<WorkoutTemplateSummary>? personalWorkouts,
    String? busyTemplateId,
    bool clearBusyTemplate = false,
    String? errorMessage,
    bool clearError = false,
    ProAccessDenied? accessDenied,
  }) => WorkoutLibraryState(
    status: status ?? this.status,
    workouts: workouts ?? this.workouts,
    personalWorkouts: personalWorkouts ?? this.personalWorkouts,
    busyTemplateId: clearBusyTemplate
        ? null
        : busyTemplateId ?? this.busyTemplateId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    accessDenied: clearError ? null : accessDenied ?? this.accessDenied,
  );

  @override
  List<Object?> get props => [
    status,
    workouts,
    personalWorkouts,
    busyTemplateId,
    errorMessage,
    accessDenied,
  ];
}
