import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';

class GetRunningReferenceCandidatesUseCase {
  const GetRunningReferenceCandidatesUseCase({
    required this.goals,
    required this.loadTroopRunningTests,
    required this.loadTroopOfficialCandidates,
    required this.loadFasCandidates,
    required this.loadProgramCandidates,
    this.hasRunningModule,
  });

  final PreparationGoalRepository goals;
  final Future<bool> Function(String programId)? hasRunningModule;
  final Future<List<RunningTestResult>> Function(String goalId)
  loadTroopRunningTests;
  final Future<List<RunningReferenceCandidate>> Function(String goalId)
  loadTroopOfficialCandidates;
  final Future<List<RunningReferenceCandidate>> Function(String goalId)
  loadFasCandidates;
  final Future<List<RunningReferenceCandidate>> Function({
    required String goalId,
    required String programId,
  })
  loadProgramCandidates;

  Future<List<RunningReferenceCandidate>> call(String goalId) async {
    final goal = (await goals.getActiveGoals())
        .where((item) => item.id == goalId)
        .firstOrNull;
    if (goal == null) throw StateError('La preparación activa no existe.');

    if (goal.programId == PreparationProgramIds.armedForcesTroopEntry) {
      final tests = await loadTroopRunningTests(goalId);
      final official = await loadTroopOfficialCandidates(goalId);
      final candidates = <RunningReferenceCandidate>[
        ...official.where(
          (item) =>
              item.goalId == goalId &&
              item.programId == goal.programId &&
              item.source == RunningReferenceSource.troopOfficialAssessment &&
              item.durationSeconds >= 120 &&
              item.durationSeconds <= 7200,
        ),
        for (final test in tests)
          if (test.id != null &&
              test.protocolVersion == 'run_2000m_v1' &&
              test.validate() == null)
            RunningReferenceCandidate(
              goalId: goalId,
              programId: goal.programId,
              recordId: test.id!,
              testId: 'run_2000_m',
              completedAt: test.completedAt,
              durationSeconds: test.durationSeconds.toDouble(),
              protocolVersion: test.protocolVersion,
              source: RunningReferenceSource.troopControl,
            ),
      ];
      candidates.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return candidates;
    }
    if (goal.programId == PreparationProgramIds.fasPeriodicAssessment) {
      final candidates = await loadFasCandidates(goalId);
      final controls = await loadTroopRunningTests(goalId);
      return [
        ...candidates.where(
          (item) =>
              item.goalId == goalId &&
              item.programId == goal.programId &&
              item.source == RunningReferenceSource.fasPeriodicAssessment &&
              item.durationSeconds >= 120 &&
              item.durationSeconds <= 7200,
        ),
        ...controls
            .where(
              (t) =>
                  t.id != null &&
                  t.protocolVersion == 'run_2000m_v1' &&
                  t.validate() == null,
            )
            .map(
              (t) => RunningReferenceCandidate(
                goalId: goalId,
                programId: goal.programId,
                recordId: t.id!,
                testId: 'run_2000_m',
                completedAt: t.completedAt,
                durationSeconds: t.durationSeconds.toDouble(),
                protocolVersion: t.protocolVersion,
                source: RunningReferenceSource.trainingControl,
              ),
            ),
      ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }
    final candidates = [
      ...await loadProgramCandidates(goalId: goalId, programId: goal.programId),
    ];
    if (await hasRunningModule?.call(goal.programId) ?? false) {
      final controls = await loadTroopRunningTests(goalId);
      candidates.addAll(
        controls
            .where(
              (t) =>
                  t.id != null &&
                  t.protocolVersion == 'run_2000m_v1' &&
                  t.validate() == null,
            )
            .map(
              (t) => RunningReferenceCandidate(
                goalId: goalId,
                programId: goal.programId,
                recordId: t.id!,
                testId: 'run_2000_m',
                completedAt: t.completedAt,
                durationSeconds: t.durationSeconds.toDouble(),
                protocolVersion: t.protocolVersion,
                source: RunningReferenceSource.trainingControl,
              ),
            ),
      );
    }
    // El caso de uso es la frontera de programa para el futuro planificador.
    return candidates
        .where(
          (item) =>
              item.goalId == goalId &&
              item.programId == goal.programId &&
              item.protocolVersion == 'run_2000m_v1' &&
              item.durationSeconds >= 120 &&
              item.durationSeconds <= 7200,
        )
        .toList(growable: false);
  }
}
