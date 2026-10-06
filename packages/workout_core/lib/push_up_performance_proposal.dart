import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart';

/// La dosis del ensayo conserva todas sus reglas; solo cambia su representación.
class PushUpPerformancePrescription extends PerformanceWorkPrescription {
  PushUpPerformancePrescription(this.dose);
  final StrengthWorkPrescription dose;
  @override
  StrengthTask get task => dose.task;
  @override
  int get estimatedSeconds => dose.estimatedSeconds;
  @override
  List<Object?> get props => [dose];
}

PerformanceModuleProposal pushUpPerformanceProposal({
  required PerformanceTrainingGoal goal,
  required StrengthTrainingDecision decision,
}) {
  if (goal.task.exerciseCode != 'push_up_standard' ||
      goal.loadMode != StrengthLoadMode.bodyweight ||
      !{
        PerformanceCapability.repetitions,
        PerformanceCapability.repetitionsInTime,
      }.contains(goal.capability)) {
    throw ArgumentError(
      'El adaptador solo representa decisiones del ensayo de flexiones.',
    );
  }
  final status = switch (decision.status) {
    StrengthDecisionStatus.ready => PerformanceProposalStatus.readyForReview,
    StrengthDecisionStatus.needsContext => PerformanceProposalStatus.needsData,
    StrengthDecisionStatus.needsCalibration =>
      PerformanceProposalStatus.needsCalibration,
    StrengthDecisionStatus.blocked => PerformanceProposalStatus.blocked,
    StrengthDecisionStatus.unsupported => PerformanceProposalStatus.unsupported,
    StrengthDecisionStatus.noSpace => PerformanceProposalStatus.agendaConflict,
  };
  if (status == PerformanceProposalStatus.readyForReview &&
      goal.task.measurement != StrengthMeasurement.reps) {
    throw ArgumentError(
      'Una dosis sin ventana temporal no cubre el objetivo cronometrado.',
    );
  }
  if (decision.sessions.any(
    (s) =>
        s.prescription.goal != goal.task ||
        s.prescription.policyVersion != PushUpRepetitionsPolicy.version,
  )) {
    throw ArgumentError(
      'La decisión no pertenece al objetivo o política esperados.',
    );
  }
  return PerformanceModuleProposal(
    goal: goal,
    status: status,
    policyStage: PerformancePolicyStage.experimental,
    policyVersion: PushUpRepetitionsPolicy.version,
    reasons: decision.reasons.map((r) => r.name),
    requirements: [
      if (status == PerformanceProposalStatus.needsData)
        PerformanceDataRequirement(
          key: 'current_context',
          reason: 'contextMissing',
        ),
      if (status == PerformanceProposalStatus.needsCalibration)
        PerformanceDataRequirement(
          key: 'comparable_working_reference',
          reason: 'calibrationMissing',
          task: goal.task,
        ),
    ],
    work: [
      for (final session in decision.sessions)
        PerformanceProposedWork(
          id: '${goal.id}/day_${session.day}',
          goalIds: [goal.id],
          prescription: PushUpPerformancePrescription(session.prescription),
          preferredDay: session.day,
        ),
    ],
  );
}
