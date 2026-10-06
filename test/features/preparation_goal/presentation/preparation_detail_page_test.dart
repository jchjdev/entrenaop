import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_detail_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> showGoal(
    WidgetTester tester,
    PreparationGoal goal, {
    RunningTestResult? runningTest,
    PhysicalAssessmentHistoryEntry? troopAssessment,
    List<RunningReferenceCandidate> runningReferences = const [],
    bool hasRunningContext = false,
  }) async {
    final cubit = PreparationDetailCubit(
      goalId: goal.id!,
      getDetail: GetPreparationDetailUseCase(
        goalRepository: _GoalRepository(goal),
        loadRunningTests: (_) async => [?runningTest],
        loadTroopAssessments: (_) async => [?troopAssessment],
        loadRunningReferenceCandidates: (_) async => runningReferences,
        scheduleRepository: _ScheduleRepository(),
      ),
      now: () => DateTime(2026, 9, 29),
    );
    await cubit.load();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          home: PreparationDetailPage(
            hasRunningContext: (_, _) async => hasRunningContext,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Tropa muestra solo su marca propia y la agenda', (tester) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'tropa-1',
        program: PreparationProgram(
          id: PreparationProgramIds.armedForcesTroopEntry,
          name: 'Ingreso · Tropa y marinería',
          kind: PreparationProgramKind.access,
          currentAssessmentCatalogVersion: 'tropa-v1',
        ),
      ),
      runningTest: RunningTestResult(
        completedAt: DateTime(2026, 9, 25),
        durationSeconds: 470,
        rpe: 8,
      ),
    );

    expect(find.text('Antecedente del historial de Tropa'), findsNothing);
    expect(find.text('Pruebas de ingreso · Tropa'), findsOneWidget);
    expect(find.text('Registrar marcas'), findsOneWidget);
    expect(find.text('Control específico · 2 km'), findsOneWidget);
    expect(find.textContaining('Última marca: 7:50'), findsOneWidget);
    expect(find.text('Explorar una semana de prueba'), findsNothing);
    expect(find.text('Laboratorio · semana de ejemplo'), findsNothing);
    expect(find.text('Evaluación de esta preparación'), findsNothing);
  });

  testWidgets('la cabecera usa su encuadre y no el de la tarjeta', (
    tester,
  ) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'cover-1',
        program: PreparationProgram(
          id: 'cover-program',
          name: 'Preparación con portada',
          kind: PreparationProgramKind.access,
          cover: PreparationProgramCover(
            cardUrl: 'https://example.test/card.jpg',
            headerUrl: 'https://example.test/header.jpg',
            focalX: 0.8,
            focalY: 0.2,
            headerFocalX: 0.6,
            headerFocalY: 0.7,
          ),
        ),
      ),
    );
    final header = tester.widget<EntrenaCard>(
      find.ancestor(
        of: find.text('Preparación con portada'),
        matching: find.byType(EntrenaCard),
      ),
    );
    expect([header.focalX, header.focalY], [0.6, 0.7]);
  });

  testWidgets('Mejora FAS conserva solo su evaluación propia', (tester) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'fas-1',
        program: PreparationProgram(
          id: PreparationProgramIds.fasPeriodicAssessment,
          name: 'Mejora FAS',
          kind: PreparationProgramKind.internalAssessment,
        ),
      ),
    );

    expect(find.text('Marcas para Mejora FAS'), findsOneWidget);
    expect(find.text('Evaluación de esta preparación'), findsNothing);
    expect(find.text('Control específico · 2 km'), findsNothing);
    expect(find.text('Explorar una semana de prueba'), findsNothing);
  });

  testWidgets('Con contexto guardado la preparación ofrece editar el plan', (
    tester,
  ) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'fas-context',
        program: PreparationProgram(
          id: PreparationProgramIds.fasPeriodicAssessment,
          name: 'Mejora FAS',
          kind: PreparationProgramKind.internalAssessment,
        ),
      ),
      hasRunningContext: true,
    );

    expect(find.text('Datos para empezar'), findsNothing);
    expect(find.text('Plan y preferencias de carrera'), findsNothing);
    expect(find.text('Mi programa'), findsOneWidget);
  });

  testWidgets('una fecha lejana conserva el objetivo y aclara el horizonte', (
    tester,
  ) async {
    final distantDate = DateTime.now().add(const Duration(days: 730));
    await showGoal(
      tester,
      PreparationGoal(
        id: 'fas-long-horizon',
        program: const PreparationProgram(
          id: PreparationProgramIds.fasPeriodicAssessment,
          name: 'Mejora FAS',
          kind: PreparationProgramKind.internalAssessment,
        ),
        targetDate: distantDate,
      ),
    );

    expect(find.textContaining('Objetivo:'), findsOneWidget);
    expect(find.textContaining('Objetivo a largo plazo'), findsOneWidget);
    expect(find.textContaining('semana a semana'), findsOneWidget);
  });

  testWidgets('la sesión completada abre su historial desde la preparación', (
    tester,
  ) async {
    const goal = PreparationGoal(
      id: 'fas-session',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'Mejora FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    );
    final cubit = PreparationDetailCubit(
      goalId: goal.id!,
      getDetail: GetPreparationDetailUseCase(
        goalRepository: const _GoalRepository(goal),
        loadRunningTests: (_) async => const [],
        loadTroopAssessments: (_) async => const [],
        loadRunningReferenceCandidates: (_) async => const [],
        scheduleRepository: _ScheduleRepository([
          ScheduledWorkout(
            id: 'scheduled-1',
            templateId: 'template-1',
            templateName: 'Carrera · fácil',
            templateVersion: 1,
            scheduledDate: DateTime(2026, 10, 5),
            source: ScheduledWorkoutSource.algorithm,
            status: ScheduledWorkoutStatus.completed,
            preparationGoalId: goal.id,
            estimatedDurationMinutes: 45,
            executionId: 'execution-1',
          ),
        ]),
      ),
      now: () => DateTime(2026, 10, 6),
    );
    await cubit.load();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const PreparationDetailPage(),
          ),
        ),
        GoRoute(
          path: '/assessment/history/workouts/:executionId',
          builder: (_, state) => Scaffold(
            body: Text('Historial ${state.pathParameters['executionId']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Carrera · fácil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carrera · fácil'));
    await tester.pumpAndSettle();
    expect(find.text('Historial execution-1'), findsOneWidget);
  });

  testWidgets('Tropa muestra una marca solo si pertenece a la preparación', (
    tester,
  ) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'tropa-2',
        program: PreparationProgram(
          id: PreparationProgramIds.armedForcesTroopEntry,
          name: 'Ingreso · Tropa y marinería',
          kind: PreparationProgramKind.access,
        ),
      ),
      troopAssessment: PhysicalAssessmentHistoryEntry(
        id: 'linked',
        completedAt: DateTime(2026, 9, 25),
        report: AssessmentReport(
          catalogVersion: 'tropa-v1',
          category: AssessmentCategory.men,
          milestone: AssessmentMilestone.entry,
          results: const [
            AssessmentResult(
              passed: true,
              mark: RecordedMark(
                testId: 'push-ups',
                unit: MarkUnit.repetitions,
                value: 12,
              ),
              standard: AssessmentStandard(
                catalogVersion: 'tropa-v1',
                test: PhysicalTestDefinition(
                  id: 'push-ups',
                  name: 'Flexiones',
                  unit: MarkUnit.repetitions,
                  betterDirection: BetterDirection.higher,
                ),
                category: AssessmentCategory.men,
                milestone: AssessmentMilestone.entry,
                threshold: 9,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Flexiones'), findsOneWidget);
    expect(find.text('12 rep'), findsOneWidget);
    expect(find.text('Registrar nuevas marcas'), findsOneWidget);
  });

  testWidgets('un programa nuevo muestra su evaluación sin tarjetas de motor', (
    tester,
  ) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'programa-1',
        program: PreparationProgram(
          id: 'programa-configurado',
          name: 'Programa configurado',
          kind: PreparationProgramKind.access,
        ),
      ),
    );

    expect(find.text('Evaluación de esta preparación'), findsOneWidget);
    expect(find.text('Carrera de 2 km vinculada'), findsNothing);
    expect(find.text('Explorar una semana de prueba'), findsNothing);
  });

  testWidgets('muestra la marca de 2 km vinculada a este programa', (
    tester,
  ) async {
    await showGoal(
      tester,
      const PreparationGoal(
        id: 'programa-1',
        program: PreparationProgram(
          id: 'programa-configurado',
          name: 'Programa configurado',
          kind: PreparationProgramKind.access,
        ),
      ),
      runningReferences: [
        RunningReferenceCandidate(
          goalId: 'programa-1',
          programId: 'programa-configurado',
          recordId: 'intento-1',
          testId: 'carrera-2k',
          completedAt: DateTime(2026, 9, 28),
          durationSeconds: 530.5,
          protocolVersion: 'run_2000m_v1',
          source: RunningReferenceSource.programAssessment,
          scoringVersion: 'v1',
        ),
      ],
    );

    expect(find.text('Marca de carrera · 2 km'), findsOneWidget);
    expect(find.textContaining('8:50.5 · 28/09/2026'), findsOneWidget);
  });

  test('un programa sin control de 2 km no consulta esas marcas', () async {
    const goal = PreparationGoal(
      id: 'generic-1',
      program: PreparationProgram(
        id: 'generic',
        name: 'Programa propio',
        kind: PreparationProgramKind.access,
      ),
    );
    final detail = await GetPreparationDetailUseCase(
      goalRepository: const _GoalRepository(goal),
      loadRunningTests: (_) async =>
          throw StateError('No debe consultar un control ajeno.'),
      loadTroopAssessments: (_) async =>
          throw StateError('No debe consultar la evaluación de Tropa.'),
      loadRunningReferenceCandidates: (_) async => const [],
      scheduleRepository: _ScheduleRepository(),
    ).call('generic-1', DateTime(2026, 9, 28), DateTime(2026, 10, 4));
    expect(detail.latestRunningTest, isNull);
  });
}

class _GoalRepository implements PreparationGoalRepository {
  const _GoalRepository(this.goal);
  final PreparationGoal goal;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [goal];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduleRepository implements WorkoutScheduleRepository {
  _ScheduleRepository([this.items = const []]);

  final List<ScheduledWorkout> items;

  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async =>
      items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
