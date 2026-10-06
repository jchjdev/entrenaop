import 'package:equatable/equatable.dart';

enum RunningReferenceSource {
  trainingControl,
  troopControl,
  troopOfficialAssessment,
  fasPeriodicAssessment,
  programAssessment,
}

/// Hecho medido en la preparación. No implica vigencia ni autoriza ritmos.
class RunningReferenceCandidate extends Equatable {
  const RunningReferenceCandidate({
    required this.goalId,
    required this.programId,
    required this.recordId,
    required this.testId,
    required this.completedAt,
    required this.durationSeconds,
    required this.protocolVersion,
    required this.source,
    this.scoringVersion,
  });

  final String goalId;
  final String programId;
  final String recordId;
  final String testId;
  final DateTime completedAt;
  final double durationSeconds;

  /// Puede faltar en catálogos históricos que no guardaban protocolo deportivo.
  final String? protocolVersion;
  final RunningReferenceSource source;
  final String? scoringVersion;

  @override
  List<Object?> get props => [
    goalId,
    programId,
    recordId,
    testId,
    completedAt,
    durationSeconds,
    protocolVersion,
    source,
    scoringVersion,
  ];
}
