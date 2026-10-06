import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reúne la marca de 2 km propia y solo la agenda de la preparación',
    () async {
      final goal = PreparationGoal(
        id: 'goal-1',
        program: const PreparationProgram(
          id: PreparationProgramIds.armedForcesTroopEntry,
          name: 'Tropa',
          kind: PreparationProgramKind.access,
        ),
        targetDate: DateTime(2027, 3, 1),
      );
      final useCase = GetPreparationDetailUseCase(
        goalRepository: _GoalRepository(goal),
        loadRunningTests: (goalId) async {
          expect(goalId, 'goal-1');
          return [
            RunningTestResult(
              completedAt: DateTime(2026, 9, 20),
              durationSeconds: 470,
              rpe: 8,
            ),
          ];
        },
        loadTroopAssessments: (_) async => const [],
        loadRunningReferenceCandidates: (_) async => const [],
        scheduleRepository: _ScheduleRepository([
          _scheduled('related', preparationGoalId: 'goal-1'),
          _scheduled('general'),
          _scheduled('other', preparationGoalId: 'goal-2'),
        ]),
      );

      final detail = await useCase(
        'goal-1',
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 27),
      );

      expect(detail.goal, goal);
      expect(detail.latestRunningTest?.durationSeconds, 470);
      expect(detail.weeklyWorkouts.map((item) => item.id), ['related']);
    },
  );
}

ScheduledWorkout _scheduled(String id, {String? preparationGoalId}) =>
    ScheduledWorkout(
      id: id,
      templateId: 'template-$id',
      templateName: 'Sesión $id',
      templateVersion: 1,
      scheduledDate: DateTime(2026, 9, 23),
      source: ScheduledWorkoutSource.user,
      status: ScheduledWorkoutStatus.planned,
      preparationGoalId: preparationGoalId,
    );

class _GoalRepository implements PreparationGoalRepository {
  const _GoalRepository(this.goal);
  final PreparationGoal goal;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [goal];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleRepository implements WorkoutScheduleRepository {
  const _ScheduleRepository(this.items);
  final List<ScheduledWorkout> items;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async =>
      items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
