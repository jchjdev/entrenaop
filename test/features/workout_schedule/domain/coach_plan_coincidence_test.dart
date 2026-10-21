import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/services/coach_plan_coincidence.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 10, 30);
ScheduledWorkout _session(
  ScheduledWorkoutSource source, {
  ScheduledWorkoutStatus status = ScheduledWorkoutStatus.planned,
  DateTime? day,
}) => ScheduledWorkout(
  id: source.name,
  templateId: 'template-${source.name}',
  templateName: source.name,
  templateVersion: 1,
  scheduledDate: day ?? _day,
  source: source,
  status: status,
);

void main() {
  test('avisa por fecha sin sustituir ni reordenar las sesiones', () {
    final workouts = List<ScheduledWorkout>.unmodifiable([
      _session(ScheduledWorkoutSource.algorithm),
      _session(ScheduledWorkoutSource.coach),
    ]);
    expect(hasCoachPlanCoincidence(workouts, _day), isTrue);
    expect(workouts.map((w) => w.id), ['algorithm', 'coach']);
    expect(
      workouts.every((w) => w.status == ScheduledWorkoutStatus.planned),
      isTrue,
    );
  });

  test('no confunde sesiones de días distintos ni años distintos', () {
    for (final otherDay in [DateTime(2026, 10, 29), DateTime(2027, 10, 30)]) {
      expect(
        hasCoachPlanCoincidence([
          _session(ScheduledWorkoutSource.coach),
          _session(ScheduledWorkoutSource.algorithm, day: otherDay),
        ], _day),
        isFalse,
      );
    }
  });

  test(
    'biblioteca, sesión personal y preparación no implican plan automático',
    () {
      for (final source in [
        ScheduledWorkoutSource.library,
        ScheduledWorkoutSource.user,
        ScheduledWorkoutSource.preparation,
        ScheduledWorkoutSource.coach,
      ]) {
        expect(
          hasCoachPlanCoincidence([
            _session(ScheduledWorkoutSource.coach),
            _session(source),
          ], _day),
          isFalse,
        );
      }
      expect(
        hasCoachPlanCoincidence([
          _session(ScheduledWorkoutSource.algorithm),
        ], _day),
        isFalse,
      );
    },
  );

  for (final status in ScheduledWorkoutStatus.values) {
    test('considera pendientes y en curso, no historial: ${status.name}', () {
      for (final source in [
        ScheduledWorkoutSource.coach,
        ScheduledWorkoutSource.algorithm,
      ]) {
        expect(
          hasCoachPlanCoincidence([
            _session(source, status: status),
            _session(
              source == ScheduledWorkoutSource.coach
                  ? ScheduledWorkoutSource.algorithm
                  : ScheduledWorkoutSource.coach,
            ),
          ], _day),
          status == ScheduledWorkoutStatus.planned ||
              status == ScheduledWorkoutStatus.inProgress,
        );
      }
    });
  }
}
