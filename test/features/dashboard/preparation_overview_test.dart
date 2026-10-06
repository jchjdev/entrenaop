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
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';

void main() {
  const paused = AdaptiveProgramProgress(
    goalId: 'paused',
    name: 'Tropa',
    status: 'paused',
    message: 'Progreso guardado.',
  );
  const current = AdaptiveProgramProgress(
    goalId: 'current',
    name: 'FAS',
    status: 'training',
    message: 'Entrena con tus datos actuales.',
  );
  const complete = AdaptiveProgramProgress(
    goalId: 'done',
    name: 'Terminado',
    status: 'complete',
    message: 'Preparación finalizada.',
  );
  PreparationOverview withPrograms(List<AdaptiveProgramProgress> programs) =>
      PreparationOverview(
        assessments: const [],
        preferences: null,
        goals: const [],
        weekStart: DateTime(2026, 10, 5),
        weeklyWorkouts: const [],
        programs: programs,
      );
  test('Inicio dirige al programa que entrena aunque otro esté pausado', () {
    expect(withPrograms([paused, complete, current]).activeProgram, current);
  });
  test('sin programa entrenando Inicio permite retomar el pausado', () {
    final overview = withPrograms([complete, paused]);
    expect(overview.activeProgram, paused);
    expect(overview.nextStep, PreparationNextStep.adaptiveProgram);
  });
  test('un programa finalizado no aparece como generador activo', () {
    expect(withPrograms([complete]).activeProgram, isNull);
  });
  test(
    'un programa iniciado lleva a entrenar aunque falte la evaluación oficial',
    () {
      final overview = PreparationOverview(
        assessments: const [],
        preferences: null,
        goals: const [],
        weekStart: DateTime(2026, 10, 5),
        weeklyWorkouts: const [],
        programs: const [
          AdaptiveProgramProgress(
            goalId: 'g',
            name: 'FAS',
            status: 'training',
            message: 'Tu semana está preparada.',
          ),
        ],
      );
      expect(overview.nextStep, PreparationNextStep.adaptiveProgram);
      expect(overview.activeProgram?.goalId, 'g');
    },
  );
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

  test(
    'el contexto actual manda sobre las preferencias antiguas en Inicio',
    () {
      PreparationOverview overview({
        required bool pain,
        required bool confirmed,
      }) => PreparationOverview(
        assessments: [assessment],
        preferences: preferences,
        goals: const [goal],
        assessedGoalIds: const {'goal-1'},
        weekStart: weekStart,
        weeklyWorkouts: const [],
        trainingContext: TrainingContext(
          availability: {'1': 45},
          equipment: {},
          reportsPain: pain,
          capacityConfirmed: confirmed,
        ),
      );
      expect(
        overview(pain: true, confirmed: true).nextStep,
        PreparationNextStep.professionalReview,
      );
      expect(
        overview(pain: false, confirmed: false).nextStep,
        PreparationNextStep.trainingPreferences,
      );
      expect(
        overview(pain: false, confirmed: true).nextStep,
        PreparationNextStep.awaitingValidatedPlan,
      );
    },
  );

  group('siguiente paso', () {
    const genericGoal = PreparationGoal(
      id: 'goal-generic',
      program: PreparationProgram(
        id: 'cnp_2026',
        name: 'Policía Nacional',
        kind: PreparationProgramKind.access,
      ),
    );

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

      expect(overview.nextStep, PreparationNextStep.assessment);
    });

    test('no envía a Tropa si solo prepara la evaluación periódica FAS', () {
      const fasGoal = PreparationGoal(
        id: 'goal-fas',
        program: PreparationProgram(
          id: PreparationProgramIds.fasPeriodicAssessment,
          name: 'Evaluación periódica FAS · 2027',
          kind: PreparationProgramKind.internalAssessment,
        ),
      );
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: null,
        goals: const [fasGoal],
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.latestAssessment, isNull);
      expect(overview.nextStep, PreparationNextStep.assessment);
    });

    test('solicita la disponibilidad tras completar la evaluación', () {
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: null,
        goals: const [goal],
        assessedGoalIds: const {'goal-1'},
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.nextStep, PreparationNextStep.trainingPreferences);
    });

    test('una evaluación Tropa no completa otro programa activo', () {
      final overview = PreparationOverview(
        assessments: [assessment],
        preferences: preferences,
        goals: const [goal, genericGoal],
        assessedGoalIds: const {'goal-1'},
        weekStart: weekStart,
        weeklyWorkouts: const [],
      );

      expect(overview.goalNeedingAssessment, genericGoal);
      expect(overview.nextStep, PreparationNextStep.assessment);
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
        assessedGoalIds: const {'goal-1'},
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
        assessedGoalIds: const {'goal-1'},
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
        refreshPrograms: () async => [],
        assessmentRepository: assessmentRepository,
        preferencesRepository: preferencesRepository,
        goalRepository: const _GoalRepository([goal]),
        scheduleRepository: scheduleRepository,
        hasFasAssessment: (_) async => false,
        hasProgramAssessment: (_) async => false,
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

  test('consulta por separado las evaluaciones de cada preparación', () async {
    const fasGoal = PreparationGoal(
      id: 'goal-fas',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'Mejora FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    );
    const cnpGoal = PreparationGoal(
      id: 'goal-cnp',
      program: PreparationProgram(
        id: 'cnp_2026',
        name: 'Policía Nacional',
        kind: PreparationProgramKind.access,
      ),
    );
    final fasRead = <String>[];
    final programRead = <String>[];
    final overview = await GetPreparationOverviewUseCase(
      refreshPrograms: () async => [],
      assessmentRepository: _AssessmentRepository([assessment]),
      preferencesRepository: _PreferencesRepository(preferences),
      goalRepository: const _GoalRepository([goal, fasGoal, cnpGoal]),
      scheduleRepository: _ScheduleRepository(),
      hasFasAssessment: (goalId) async {
        fasRead.add(goalId);
        return true;
      },
      hasProgramAssessment: (goalId) async {
        programRead.add(goalId);
        return false;
      },
    )();

    expect(fasRead, ['goal-fas']);
    expect(programRead, ['goal-cnp']);
    expect(overview.assessedGoalIds, {'goal-1', 'goal-fas'});
    expect(overview.goalNeedingAssessment, cnpGoal);
  });

  test('el cubit conserva un error recuperable si falla la carga', () async {
    final cubit = DashboardCubit(
      getOverview: GetPreparationOverviewUseCase(
        refreshPrograms: () async => [],
        assessmentRepository: _AssessmentRepository(const [], fail: true),
        preferencesRepository: _PreferencesRepository(null),
        goalRepository: const _GoalRepository([goal]),
        scheduleRepository: _ScheduleRepository(),
        hasFasAssessment: (_) async => false,
        hasProgramAssessment: (_) async => false,
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
    throw StateError('El inicio no debe leer el historial general.');
  }

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistoryForGoal(
    String goalId,
  ) async {
    if (fail) throw Exception('fallo simulado');
    expect(goalId, 'goal-1');
    return history;
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
    String? goalId,
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
