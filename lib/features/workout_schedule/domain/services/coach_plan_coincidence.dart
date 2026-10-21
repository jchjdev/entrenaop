import '../entities/scheduled_workout.dart';

/// Coincidencia de fecha; no diagnostica solapamiento horario ni carga deportiva.
/// Solo observa la agenda: no sustituye, pausa ni reprograma ninguna sesión.
bool hasCoachPlanCoincidence(
  Iterable<ScheduledWorkout> workouts,
  DateTime day,
) {
  var coach = false;
  var algorithm = false;
  for (final item in workouts) {
    final date = item.scheduledDate;
    if (date.year != day.year ||
        date.month != day.month ||
        date.day != day.day ||
        (item.status != ScheduledWorkoutStatus.planned &&
            item.status != ScheduledWorkoutStatus.inProgress)) {
      continue;
    }
    coach |= item.source == ScheduledWorkoutSource.coach;
    algorithm |= item.source == ScheduledWorkoutSource.algorithm;
    if (coach && algorithm) return true;
  }
  return false;
}
