import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reúne la última evaluación compatible y solo la agenda de la preparación',
    () async {
      final goal = PreparationGoal(
        id: 'goal-1',
        program: const PreparationProgram(
          id: 'troop',
          name: 'Tropa',
          kind: PreparationProgramKind.access,
          currentAssessmentCatalogVersion: 'catalog-v1',
        ),
        targetDate: DateTime(2027, 3, 1),
      );
      final useCase = GetPreparationDetailUseCase(
        goalRepository: _GoalRepository(goal),
        assessmentRepository: _AssessmentRepository([
          _assessment('newer-other', 'catalog-v2', DateTime(2026, 9, 22)),
          _assessment('compatible', 'catalog-v1', DateTime(2026, 9, 20)),
        ]),
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
      expect(detail.latestAssessment?.id, 'compatible');
      expect(detail.weeklyWorkouts.map((item) => item.id), ['related']);
    },
  );
}

PhysicalAssessmentHistoryEntry _assessment(
  String id,
  String catalogVersion,
  DateTime completedAt,
) {
  const test = PhysicalTestDefinition(
    id: 'push-ups',
    name: 'Flexiones',
    unit: MarkUnit.repetitions,
    betterDirection: BetterDirection.higher,
  );
  return PhysicalAssessmentHistoryEntry(
    id: id,
    completedAt: completedAt,
    report: AssessmentReport(
      catalogVersion: catalogVersion,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      results: const [
        AssessmentResult(
          passed: true,
          mark: RecordedMark(
            testId: 'push-ups',
            unit: MarkUnit.repetitions,
            value: 18,
          ),
          standard: AssessmentStandard(
            catalogVersion: 'catalog-v1',
            test: test,
            category: AssessmentCategory.men,
            milestone: AssessmentMilestone.entry,
            threshold: 10,
          ),
        ),
      ],
    ),
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

class _AssessmentRepository implements PhysicalAssessmentRepository {
  const _AssessmentRepository(this.history);
  final List<PhysicalAssessmentHistoryEntry> history;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async => history;

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
