import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/presentation/home_day_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 10, 5);
ScheduledWorkout _item(
  String id,
  ScheduledWorkoutStatus status, {
  String? goalId,
  String? executionId,
  int day = 5,
}) => ScheduledWorkout(
  id: id,
  templateId: 'template-$id',
  templateName: 'Sesión $id',
  templateVersion: 1,
  scheduledDate: DateTime(2026, 10, day),
  source: ScheduledWorkoutSource.algorithm,
  status: status,
  preparationGoalId: goalId,
  executionId: executionId,
);
PreparationOverview _overview(List<ScheduledWorkout> items) =>
    PreparationOverview(
      assessments: const [],
      preferences: null,
      goals: const [],
      weekStart: _day,
      weeklyWorkouts: items,
      programs: const [
        AdaptiveProgramProgress(
          goalId: 'current',
          name: 'FAS',
          status: 'training',
          message: '',
        ),
      ],
    );

void main() {
  test('selecciona la fecha sin traer otra sesión ni alterar la agenda', () {
    final items = [
      _item('today', ScheduledWorkoutStatus.planned),
      _item('other', ScheduledWorkoutStatus.planned, day: 7),
    ];
    expect(homeWorkoutsForDay(_overview(items), _day).map((w) => w.id), [
      'today',
    ]);
    expect(
      homeWorkoutsForDay(_overview(items), DateTime(2026, 10, 6)),
      isEmpty,
    );
    expect(items.map((w) => w.id), ['today', 'other']);
  });
  test('retomar precede al programa; pendiente precede a completada', () {
    final result = homeWorkoutsForDay(
      _overview([
        _item('done', ScheduledWorkoutStatus.completed),
        _item('planned', ScheduledWorkoutStatus.planned, goalId: 'current'),
        _item('resume', ScheduledWorkoutStatus.inProgress),
      ]),
      _day,
    );
    expect(result.map((w) => w.id), ['resume', 'planned', 'done']);
  });
  test('el programa en curso tiene prioridad entre sesiones pendientes', () {
    expect(
      homeWorkoutsForDay(
        _overview([
          _item('extra', ScheduledWorkoutStatus.planned),
          _item('program', ScheduledWorkoutStatus.planned, goalId: 'current'),
        ]),
        _day,
      ).first.id,
      'program',
    );
  });
  test(
    'la sesión programada abre agenda, nunca ejecuta la plantilla suelta',
    () {
      expect(
        homeWorkoutRoute(_item('assigned', ScheduledWorkoutStatus.planned)),
        '/plan/week?date=2026-10-05&session=assigned',
      );
    },
  );
  test('retoma la ejecución existente y abre resultados sin empezar otra', () {
    expect(
      homeWorkoutRoute(
        _item(
          'resume',
          ScheduledWorkoutStatus.inProgress,
          executionId: 'run-1',
        ),
      ),
      '/plan/week/active/run-1',
    );
    expect(
      homeWorkoutRoute(
        _item('done', ScheduledWorkoutStatus.completed, executionId: 'run-2'),
      ),
      '/assessment/history/workouts/run-2',
    );
    expect(
      homeWorkoutRoute(
        _item(
          'stopped',
          ScheduledWorkoutStatus.abandoned,
          executionId: 'run-3',
        ),
      ),
      '/assessment/history/workouts/run-3',
    );
  });
}
