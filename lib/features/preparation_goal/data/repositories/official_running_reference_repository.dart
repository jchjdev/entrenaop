import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';

/// Lee marcas oficiales existentes sin copiar puntos ni modificar intentos.
class OfficialRunningReferenceRepository {
  const OfficialRunningReferenceRepository({
    required this.troopAssessments,
    required this.fasAssessments,
  });

  final PhysicalAssessmentRepository troopAssessments;
  final FasPeriodicAssessmentRepository fasAssessments;

  Future<List<RunningReferenceCandidate>> forTroopGoal(String goalId) async =>
      troopOfficialRunningCandidates(
        goalId: goalId,
        entries: await troopAssessments.getHistoryForGoal(goalId),
      );

  Future<List<RunningReferenceCandidate>> forFasGoal(String goalId) async =>
      fasPeriodicRunningCandidates(
        goalId: goalId,
        entries: await fasAssessments.history(goalId: goalId),
      );
}

List<RunningReferenceCandidate> troopOfficialRunningCandidates({
  required String goalId,
  required List<PhysicalAssessmentHistoryEntry> entries,
}) {
  final candidates = <RunningReferenceCandidate>[];
  for (final entry in entries) {
    for (final result in entry.report.results) {
      final mark = result.mark;
      if (mark.testId != 'run_2000_m' ||
          mark.unit != MarkUnit.milliseconds ||
          mark.value <= 0) {
        continue;
      }
      candidates.add(
        RunningReferenceCandidate(
          goalId: goalId,
          programId: PreparationProgramIds.armedForcesTroopEntry,
          recordId: entry.id,
          testId: mark.testId,
          completedAt: entry.completedAt,
          durationSeconds: mark.value / 1000,
          // El catálogo antiguo no conserva un protocolo deportivo versionado.
          protocolVersion: null,
          source: RunningReferenceSource.troopOfficialAssessment,
          scoringVersion: entry.report.catalogVersion,
        ),
      );
    }
  }
  candidates.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return candidates;
}

List<RunningReferenceCandidate> fasPeriodicRunningCandidates({
  required String goalId,
  required List<FasPeriodicAssessmentEntry> entries,
}) {
  final candidates = <RunningReferenceCandidate>[];
  for (final entry in entries) {
    // El historial personal sin asociación explícita no pertenece al plan.
    if (entry.goalId != goalId) continue;
    for (final mark in entry.marks) {
      if (mark.testId != 'run_2000_m' ||
          mark.unit != 'milliseconds' ||
          mark.value <= 0) {
        continue;
      }
      candidates.add(
        RunningReferenceCandidate(
          goalId: goalId,
          programId: PreparationProgramIds.fasPeriodicAssessment,
          recordId: entry.id,
          testId: mark.testId,
          completedAt: entry.completedAt,
          durationSeconds: mark.value / 1000,
          // El baremo FAS identifica la norma, pero no versiona el protocolo.
          protocolVersion: null,
          source: RunningReferenceSource.fasPeriodicAssessment,
          scoringVersion: entry.scoringVersion,
        ),
      );
    }
  }
  candidates.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return candidates;
}
