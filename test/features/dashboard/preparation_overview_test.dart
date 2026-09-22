import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final weekStart = DateTime(2026, 9, 21);
  final assessment = _assessment();
  const program = PreparationProgram(
    id: PreparationProgramIds.armedForcesTroopEntry,
    name: 'Ingreso · Tropa y marinería',
    kind: PreparationProgramKind.access,
  );
  const goal = PreparationGoal(id: 'goal-1', program: program);
  const preferences = TrainingPreferences(
    availableDaysPerWeek: 3,
    sessionDurationMinutes: 60,
    experience: TrainingExperience.occasional,
    equipment: {TrainingEquipment.none},
    requiresProfessionalReview: false,
  );

  group('siguiente paso', () {
    test('solicita primero el objetivo de preparación', () {
      final overview = PreparationOverview(
        assessments: const [],
        preferences: null,
        goals: const [],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.preparationGoal);
    });

    test('solicita la evaluación física después del objetivo', () {
      final overview = PreparationOverview(
        assessments: const [],
        preferences: null,
        goals: const [goal],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.physicalAssessment);
    });

    test('solicita la disponibilidad tras completar la evaluación', () {
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: null,
        goals: const [goal],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.trainingPreferences);
    });

    test('bloquea el plan cuando se ha pedido revisión profesional', () {
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: const TrainingPreferences(
          availableDaysPerWeek: 3,
          sessionDurationMinutes: 60,
          experience: TrainingExperience.starting,
          equipment: {TrainingEquipment.none},
          requiresProfessionalReview: true,
        ),
        goals: const [goal],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.professionalReview);
    });

    test('espera reglas validadas cuando el contexto está completo', () {
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: preferences,
        goals: const [goal],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.awaitingValidatedPlan);
    });
  });

  test('el cubit reúne evaluación y disponibilidad', () async {
    final assessmentRepository = _AssessmentRepository([assessment]);
    final preferencesRepository = _PreferencesRepository(preferences);
    final scheduled = ScheduledWorkout(
      id: 'scheduled-1',
      templateId: 'template-1',
      templateName: 'Sesión libre',
      templateVersion: 1,
      scheduledDate: DateTime(2026, 9, 22),
      source: ScheduledWorkoutSource.user,
      status: ScheduledWorkoutStatus.planned,
    );
    final scheduleRepository = _ScheduleRepository([scheduled]);
    final cubit = DashboardCubit(
      getOverview: GetPreparationOverviewUseCase(
        assessmentRepository: assessmentRepository,
        preferencesRepository: preferencesRepository,
        goalRepository: const _GoalRepository([goal]),
        scheduleRepository: scheduleRepository,
        now: () => DateTime(2026, 9, 22),
      ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, DashboardStatus.loaded);
    expect(cubit.state.overview?.latestAssessment, assessment);
    expect(cubit.state.overview?.preferences, preferences);
    expect(cubit.state.overview?.goals, [goal]);
    expect(cubit.state.overview?.weekStart, weekStart);
    expect(cubit.state.overview?.weeklyWorkouts, [scheduled]);
    expect(scheduleRepository.lastStart, weekStart);
    expect(scheduleRepository.lastEnd, DateTime(2026, 9, 27));
  });

  test('el cubit conserva un error recuperable si falla la carga', () async {
    final cubit = DashboardCubit(
      getOverview: GetPreparationOverviewUseCase(
        assessmentRepository: _AssessmentRepository(const [], fail: true),
        preferencesRepository: _PreferencesRepository(null),
        goalRepository: const _GoalRepository([]),
        scheduleRepository: _ScheduleRepository(),
      ),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, DashboardStatus.failure);
    expect(cubit.state.errorMessage, isNotEmpty);
  });
}

PhysicalAssessmentHistoryEntry _assessment() {
  const test = PhysicalTestDefinition(
    id: 'push_ups',
    name: 'Extensiones de brazos',
    unit: MarkUnit.repetitions,
    betterDirection: BetterDirection.higher,
  );
  const standard = AssessmentStandard(
    catalogVersion: 'test-v1',
    test: test,
    category: AssessmentCategory.men,
    milestone: AssessmentMilestone.entry,
    threshold: 10,
  );
  return PhysicalAssessmentHistoryEntry(
    id: 'assessment-1',
    completedAt: DateTime.utc(2026, 9, 20),
    report: AssessmentReport(
      catalogVersion: 'test-v1',
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      results: const [
        AssessmentResult(
          passed: true,
          mark: RecordedMark(
            testId: 'push_ups',
            unit: MarkUnit.repetitions,
            value: 12,
          ),
          standard: standard,
        ),
      ],
    ),
  );
}

class _AssessmentRepository implements PhysicalAssessmentRepository {
  const _AssessmentRepository(this.history, {this.fail = false});

  final List<PhysicalAssessmentHistoryEntry> history;
  final bool fail;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async {
    if (fail) throw Exception('fallo simulado');
    return history;
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }
}

class _PreferencesRepository implements TrainingPreferencesRepository {
  const _PreferencesRepository(this.preferences);

  final TrainingPreferences? preferences;

  @override
  Future<TrainingPreferences?> get() async => preferences;

  @override
  Future<void> save(TrainingPreferences preferences) {
    throw UnimplementedError();
  }
}

class _GoalRepository implements PreparationGoalRepository {
  const _GoalRepository(this.goals);

  final List<PreparationGoal> goals;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => goals;

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => const [];

  @override
  Future<PreparationGoal> save(PreparationGoal goal) {
    throw UnimplementedError();
  }

  @override
  Future<void> archive(String goalId) => throw UnimplementedError();
}

class _ScheduleRepository implements WorkoutScheduleRepository {
  _ScheduleRepository([this.items = const []]);

  final List<ScheduledWorkout> items;
  DateTime? lastStart;
  DateTime? lastEnd;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async {
    lastStart = start;
    lastEnd = end;
    return items;
  }

  @override
  Future<String> schedule(String templateId, DateTime date, {String? time}) =>
      throw UnimplementedError();

  @override
  Future<void> reschedule(String scheduledId, DateTime date, {String? time}) =>
      throw UnimplementedError();

  @override
  Future<void> cancel(String scheduledId) => throw UnimplementedError();

  @override
  Future<String> start(String scheduledId) => throw UnimplementedError();
}
