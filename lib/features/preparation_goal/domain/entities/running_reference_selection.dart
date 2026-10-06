import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';

/// Elección explícita de un intento; la marca se lee siempre del registro original.
class RunningReferenceSelection {
  const RunningReferenceSelection({
    required this.goalId,
    required this.source,
    required this.recordId,
    required this.selectedAt,
    this.continuityConfirmedAt,
  });

  final String goalId;
  final RunningReferenceSource source;
  final String recordId;
  final DateTime selectedAt;
  final DateTime? continuityConfirmedAt;

  bool matches(RunningReferenceCandidate candidate) =>
      goalId == candidate.goalId &&
      source == candidate.source &&
      recordId == candidate.recordId;
}
