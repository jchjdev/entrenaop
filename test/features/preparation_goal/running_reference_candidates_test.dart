import 'package:entrenaop/features/preparation_goal/data/repositories/program_running_reference_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_running_reference_candidates_usecase.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const troop = PreparationGoal(
    id: 'troop-goal',
    program: PreparationProgram(
      id: PreparationProgramIds.armedForcesTroopEntry,
      name: 'Tropa',
      kind: PreparationProgramKind.access,
    ),
  );
  const cnp = PreparationGoal(
    id: 'cnp-goal',
    program: PreparationProgram(
      id: 'cnp_2026',
      name: 'Policía Nacional',
      kind: PreparationProgramKind.access,
    ),
  );
  const fas = PreparationGoal(
    id: 'fas-goal',
    program: PreparationProgram(
      id: PreparationProgramIds.fasPeriodicAssessment,
      name: 'Mejora FAS',
      kind: PreparationProgramKind.internalAssessment,
    ),
  );

  for (final goal in [fas, cnp]) {
    test(
      'control de entrenamiento sin evaluación oficial: ${goal.programId}',
      () async {
        final usecase = GetRunningReferenceCandidatesUseCase(
          goals: _Goals([goal]),
          hasRunningModule: (_) async => true,
          loadTroopRunningTests: (id) async {
            expect(id, goal.id);
            return [
              RunningTestResult(
                id: 'control',
                completedAt: DateTime(2026, 10, 4),
                durationSeconds: 478,
                rpe: 8,
              ),
            ];
          },
          loadTroopOfficialCandidates: (_) async => const [],
          loadFasCandidates: (_) async => const [],
          loadProgramCandidates: ({
            required goalId,
            required programId,
          }) async => const [],
        );
        final result = await usecase(goal.id!);
        expect(result.single.source, RunningReferenceSource.trainingControl);
        expect(result.single.goalId, goal.id);
        expect(result.single.durationSeconds, 478);
        expect(result.single.scoringVersion, isNull);
      },
    );
  }

  test('solo la prueba vinculada aporta una marca, nunca sus puntos', () {
    final values = runningCandidatesFromProgramAttempts(
      goalId: 'cnp-goal',
      programId: 'cnp_2026',
      boundTestIds: {'run-test'},
      attempts: [
        ProgramAssessmentAttempt(
          id: 'attempt-1',
          assessedOn: DateTime(2026, 9, 28),
          category: 'men',
          result: const ProgramAssessmentResult(
            passed: true,
            age: 30,
            version: 'cnp-v1',
            total: 20,
            details: [
              ProgramAssessmentDetail(
                testId: 'run-test',
                name: 'Carrera',
                passed: true,
                mark: 480.5,
                points: 8,
              ),
              ProgramAssessmentDetail(
                testId: 'agility-test',
                name: 'Agilidad',
                passed: true,
                mark: 10,
                points: 6,
              ),
            ],
          ),
        ),
      ],
    );

    expect(values, hasLength(1));
    expect(values.single.durationSeconds, 480.5);
    expect(values.single.scoringVersion, 'cnp-v1');
    expect(values.single.source, RunningReferenceSource.programAssessment);
  });

  test(
    'el control de Tropa no toma la marca oficial ni otro programa',
    () async {
      final usecase = GetRunningReferenceCandidatesUseCase(
        goals: const _Goals([troop, cnp, fas]),
        loadTroopRunningTests: (goalId) async => [
          RunningTestResult(
            id: 'control-1',
            completedAt: DateTime(2026, 9, 28),
            durationSeconds: 500,
            rpe: 8,
          ),
        ],
        loadTroopOfficialCandidates: (_) async => const [],
        loadFasCandidates: (_) async => const [],
        loadProgramCandidates: ({required goalId, required programId}) async =>
            [
              RunningReferenceCandidate(
                goalId: 'other-goal',
                programId: programId,
                recordId: 'wrong',
                testId: 'run-test',
                completedAt: DateTime(2026, 9, 28),
                durationSeconds: 480,
                protocolVersion: 'run_2000m_v1',
                source: RunningReferenceSource.programAssessment,
              ),
            ],
      );

      final troopValues = await usecase('troop-goal');
      expect(troopValues, hasLength(1));
      expect(troopValues.single.recordId, 'control-1');
      expect(troopValues.single.source, RunningReferenceSource.troopControl);
      expect(await usecase('cnp-goal'), isEmpty);
      expect(() => usecase('missing'), throwsStateError);
    },
  );

  test('FAS solo devuelve intentos vinculados a su preparación', () async {
    final usecase = GetRunningReferenceCandidatesUseCase(
      goals: const _Goals([fas]),
      loadTroopRunningTests: (_) async => const [],
      loadTroopOfficialCandidates: (_) async => const [],
      loadFasCandidates: (_) async => [
        RunningReferenceCandidate(
          goalId: 'other-goal',
          programId: PreparationProgramIds.fasPeriodicAssessment,
          recordId: 'foreign',
          testId: 'run_2000_m',
          completedAt: DateTime.utc(2026, 9, 28),
          durationSeconds: 600,
          protocolVersion: null,
          source: RunningReferenceSource.fasPeriodicAssessment,
        ),
        RunningReferenceCandidate(
          goalId: 'fas-goal',
          programId: PreparationProgramIds.fasPeriodicAssessment,
          recordId: 'own',
          testId: 'run_2000_m',
          completedAt: DateTime.utc(2026, 9, 27),
          durationSeconds: 650,
          protocolVersion: null,
          source: RunningReferenceSource.fasPeriodicAssessment,
        ),
      ],
      loadProgramCandidates: ({required goalId, required programId}) async =>
          const [],
    );
    final values = await usecase('fas-goal');
    expect(values, hasLength(1));
    expect(values.single.recordId, 'own');
  });
}

class _Goals implements PreparationGoalRepository {
  const _Goals(this.values);
  final List<PreparationGoal> values;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => values;

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async =>
      values.map((goal) => goal.program).toList();

  @override
  Future<PreparationGoal> save(PreparationGoal goal) async => goal;

  @override
  Future<void> archive(String goalId) async {}
}
