import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramRunningReferenceRepository {
  const ProgramRunningReferenceRepository({
    required this.client,
    required this.assessments,
  });

  final SupabaseClient client;
  final ProgramAssessmentRepository assessments;

  Future<bool> hasRunningModule(String programId) async =>
      (await client
              .from('program_training_modules')
              .select('test_id')
              .eq('program_id', programId)
              .eq('module_key', 'running_2000m_v1')
              .limit(1))
          .isNotEmpty;

  Future<List<RunningReferenceCandidate>> forGoal({
    required String goalId,
    required String programId,
  }) async {
    final modules = await client
        .from('program_training_modules')
        .select('test_id')
        .eq('program_id', programId)
        .eq('module_key', 'running_2000m_v1');
    if (modules.isEmpty) return const [];
    final boundTestIds = {for (final row in modules) row['test_id'] as String};
    final attempts = await assessments.history(goalId);
    return runningCandidatesFromProgramAttempts(
      goalId: goalId,
      programId: programId,
      boundTestIds: boundTestIds,
      attempts: attempts,
    );
  }
}

List<RunningReferenceCandidate> runningCandidatesFromProgramAttempts({
  required String goalId,
  required String programId,
  required Set<String> boundTestIds,
  required List<ProgramAssessmentAttempt> attempts,
}) {
  final candidates = <RunningReferenceCandidate>[];
  for (final attempt in attempts) {
    for (final detail in attempt.result.details) {
      if (!boundTestIds.contains(detail.testId)) continue;
      final mark = detail.mark;
      if (mark == null || !mark.isFinite || mark <= 0) {
        continue;
      }
      // El vínculo ADMIN garantiza segundos, 2.000 m y run_2000m_v1 en SQL.
      candidates.add(
        RunningReferenceCandidate(
          goalId: goalId,
          programId: programId,
          recordId: attempt.id,
          testId: detail.testId,
          completedAt: attempt.assessedOn,
          durationSeconds: mark,
          protocolVersion: 'run_2000m_v1',
          source: RunningReferenceSource.programAssessment,
          scoringVersion: attempt.result.version,
        ),
      );
    }
  }
  candidates.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return candidates;
}
