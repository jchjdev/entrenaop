import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';

/// Orden de presentación de sesiones ya asignadas, no una regla de prescripción.
List<ScheduledWorkout> homeWorkoutsForDay(
  PreparationOverview overview,
  DateTime day,
) {
  final items = overview.weeklyWorkouts
      .where(
        (item) =>
            item.scheduledDate.year == day.year &&
            item.scheduledDate.month == day.month &&
            item.scheduledDate.day == day.day,
      )
      .toList();
  int priority(ScheduledWorkout item) => switch (item.status) {
    ScheduledWorkoutStatus.inProgress => 0,
    ScheduledWorkoutStatus.planned => 1,
    ScheduledWorkoutStatus.completed => 2,
    ScheduledWorkoutStatus.abandoned => 3,
    ScheduledWorkoutStatus.skipped => 4,
  };
  items.sort((a, b) {
    final status = priority(a).compareTo(priority(b));
    if (status != 0) return status;
    final current = overview.activeProgram;
    if (current?.isCurrent == true) {
      final aCurrent = a.preparationGoalId == current!.goalId;
      final bCurrent = b.preparationGoalId == current.goalId;
      if (aCurrent != bCurrent) return aCurrent ? -1 : 1;
    }
    final time = (a.scheduledTime ?? '99:99').compareTo(
      b.scheduledTime ?? '99:99',
    );
    return time != 0 ? time : a.id.compareTo(b.id);
  });
  return items;
}

String homeDateParam(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String homeWorkoutRoute(ScheduledWorkout item) {
  if (item.status == ScheduledWorkoutStatus.inProgress &&
      item.executionId != null) {
    return '/plan/week/active/${item.executionId}';
  }
  if ((item.status == ScheduledWorkoutStatus.completed ||
          item.status == ScheduledWorkoutStatus.abandoned) &&
      item.executionId != null) {
    return '/assessment/history/workouts/${item.executionId}';
  }
  // Se abre la agenda: empezar desde una plantilla suelta perdería su vínculo.
  return '/plan/week?date=${homeDateParam(item.scheduledDate)}&session=${Uri.encodeQueryComponent(item.id)}';
}
