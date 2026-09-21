import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum WorkoutScheduleStatus { initial, loading, ready, failure }

class WorkoutScheduleState extends Equatable {
  const WorkoutScheduleState({
    required this.weekStart,
    required this.selectedDay,
    this.status = WorkoutScheduleStatus.initial,
    this.items = const [],
    this.publicTemplates = const [],
    this.personalTemplates = const [],
    this.busyItemId,
    this.errorMessage,
  });

  final WorkoutScheduleStatus status;
  final DateTime weekStart;
  final DateTime selectedDay;
  final List<ScheduledWorkout> items;
  final List<WorkoutTemplateSummary> publicTemplates;
  final List<WorkoutTemplateSummary> personalTemplates;
  final String? busyItemId;
  final String? errorMessage;

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  List<ScheduledWorkout> get selectedItems => items
      .where((item) => _sameDate(item.scheduledDate, selectedDay))
      .toList(growable: false);

  WorkoutScheduleState copyWith({
    WorkoutScheduleStatus? status,
    DateTime? weekStart,
    DateTime? selectedDay,
    List<ScheduledWorkout>? items,
    List<WorkoutTemplateSummary>? publicTemplates,
    List<WorkoutTemplateSummary>? personalTemplates,
    String? busyItemId,
    bool clearBusy = false,
    String? errorMessage,
    bool clearError = false,
  }) => WorkoutScheduleState(
    status: status ?? this.status,
    weekStart: weekStart ?? this.weekStart,
    selectedDay: selectedDay ?? this.selectedDay,
    items: items ?? this.items,
    publicTemplates: publicTemplates ?? this.publicTemplates,
    personalTemplates: personalTemplates ?? this.personalTemplates,
    busyItemId: clearBusy ? null : busyItemId ?? this.busyItemId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    weekStart,
    selectedDay,
    items,
    publicTemplates,
    personalTemplates,
    busyItemId,
    errorMessage,
  ];
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
