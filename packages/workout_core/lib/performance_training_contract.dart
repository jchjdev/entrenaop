import 'package:equatable/equatable.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart' show StrengthTask;

/// La capacidad deportiva se declara; no se deduce del nombre o de los músculos.
enum PerformanceCapability {
  running,
  repetitions,
  repetitionsInTime,
  maximalStrength,
  isometricEndurance,
  ropeClimb,
  carry,
  jumpOrThrow,
  powerPractice,
  plannedCourse,
  reactiveAgility;

  bool accepts(StrengthMeasurement measurement) => switch (this) {
    running => {
      StrengthMeasurement.timeForDistance,
      StrengthMeasurement.distance,
    }.contains(measurement),
    repetitions => {
      StrengthMeasurement.reps,
      StrengthMeasurement.loadReps,
    }.contains(measurement),
    repetitionsInTime => measurement == StrengthMeasurement.repsInTime,
    maximalStrength => measurement == StrengthMeasurement.maxLoad,
    isometricEndurance => measurement == StrengthMeasurement.duration,
    ropeClimb => {
      StrengthMeasurement.timeForDistance,
      StrengthMeasurement.passFail,
    }.contains(measurement),
    carry => {
      StrengthMeasurement.distance,
      StrengthMeasurement.duration,
    }.contains(measurement),
    jumpOrThrow => {
      StrengthMeasurement.distance,
      StrengthMeasurement.height,
    }.contains(measurement),
    powerPractice => {
      StrengthMeasurement.reps,
      StrengthMeasurement.loadReps,
      StrengthMeasurement.reactiveMetrics,
    }.contains(measurement),
    plannedCourse => measurement == StrengthMeasurement.timeForCourse,
    reactiveAgility => {
      StrengthMeasurement.timeForCourse,
      StrengthMeasurement.passFail,
    }.contains(measurement),
  };
}

/// Agrupación de preguntas. No determina la dosis ni la transferencia deportiva.
enum PerformanceQuestionBlock {
  running,
  pushes,
  pulls,
  isometrics,
  strengthAndLowerBody,
  rope,
  carries,
  jumpsAndThrows,
  powerAndReactivity,
  coursesAndAgility,
  trunk,
}

class PerformanceTrainingGoal extends Equatable {
  PerformanceTrainingGoal({
    required this.id,
    required this.capability,
    required this.questionBlock,
    required this.task,
    required this.loadMode,
  }) {
    _checkText(id);
    if (!capability.accepts(task.measurement) ||
        ((task.measurement == StrengthMeasurement.loadReps ||
                task.measurement == StrengthMeasurement.maxLoad) &&
            loadMode != StrengthLoadMode.externalLoad &&
            loadMode != StrengthLoadMode.bodyweightPlusExternal)) {
      throw ArgumentError('Objetivo, medición y carga incompatibles.');
    }
  }

  final String id;
  final PerformanceCapability capability;
  final PerformanceQuestionBlock questionBlock;
  final StrengthTask task;
  final StrengthLoadMode loadMode;

  /// Comprueba representación del catálogo; no acredita una política disponible.
  bool isRepresentedBy(StrengthExerciseDefinition definition) =>
      definition.code == task.exerciseCode &&
      definition.definitionVersion == task.exerciseVersion &&
      definition.supports(task.measurement, loadMode) &&
      switch (capability) {
        // Carrera mantiene su catálogo/motor propios, fuera de esta biblioteca.
        PerformanceCapability.running => false,
        PerformanceCapability.isometricEndurance =>
          definition.movementModes.contains('isometric'),
        PerformanceCapability.ropeClimb => definition.movementPatterns.contains(
          'rope_climb',
        ),
        PerformanceCapability.carry => definition.movementPatterns.contains(
          'carry',
        ),
        PerformanceCapability.jumpOrThrow => definition.movementPatterns.any(
          (pattern) =>
              pattern.startsWith('plyometric_') || pattern == 'ballistic_throw',
        ),
        PerformanceCapability.plannedCourse =>
          definition.movementPatterns.contains('change_of_direction') &&
              !definition.movementPatterns.contains('reactive_agility'),
        PerformanceCapability.reactiveAgility =>
          definition.movementPatterns.contains('reactive_agility'),
        _ => true,
      };

  @override
  List<Object?> get props => [id, capability, questionBlock, task, loadMode];
}

enum PerformanceProposalStatus {
  readyForReview,
  needsData,
  needsCalibration,
  blocked,
  unsupported,
  agendaConflict,
}

enum PerformancePolicyStage { unavailable, experimental, reviewed }

class PerformanceDataRequirement extends Equatable {
  PerformanceDataRequirement({
    required this.key,
    required this.reason,
    this.task,
  }) {
    _checkText(key);
    _checkText(reason);
  }
  final String key;
  final String reason;

  /// Nulo para datos comunes; una referencia de variante conserva su identidad.
  final StrengthTask? task;
  @override
  List<Object?> get props => [key, reason, task];
}

/// Cada estrategia mantiene su dosis tipada; el intercambio no impone RIR o reps.
abstract class PerformanceWorkPrescription extends Equatable {
  StrengthTask get task;
  int get estimatedSeconds;
}

class PerformanceProposedWork extends Equatable {
  PerformanceProposedWork({
    required this.id,
    required Iterable<String> goalIds,
    required this.prescription,
    required this.preferredDay,
  }) : goalIds = Set.unmodifiable(goalIds) {
    _checkText(id);
    if (this.goalIds.isEmpty ||
        preferredDay < 0 ||
        preferredDay > 6 ||
        prescription.estimatedSeconds <= 0) {
      throw ArgumentError('Propuesta de trabajo no válida.');
    }
    for (final goalId in this.goalIds) {
      _checkText(goalId);
    }
  }
  final String id;
  final Set<String> goalIds;
  final PerformanceWorkPrescription prescription;

  /// Preferencia de la estrategia; no constituye un día publicado por coordinación.
  final int preferredDay;
  @override
  List<Object?> get props => [id, goalIds, prescription, preferredDay];
}

class PerformanceModuleProposal {
  PerformanceModuleProposal({
    required this.goal,
    required this.status,
    required this.policyStage,
    required Iterable<String> reasons,
    this.policyVersion,
    Iterable<PerformanceDataRequirement> requirements = const [],
    Iterable<PerformanceProposedWork> work = const [],
  }) : reasons = List.unmodifiable(reasons),
       requirements = List.unmodifiable(requirements),
       work = List.unmodifiable(work) {
    if (policyVersion != null) _checkText(policyVersion!);
    for (final reason in this.reasons) {
      _checkText(reason);
    }
    if (this.reasons.isEmpty ||
        (policyStage == PerformancePolicyStage.unavailable &&
            (policyVersion != null ||
                status != PerformanceProposalStatus.unsupported)) ||
        (policyStage != PerformancePolicyStage.unavailable &&
            policyVersion == null) ||
        (status == PerformanceProposalStatus.readyForReview &&
            (this.work.isEmpty || this.requirements.isNotEmpty)) ||
        (status != PerformanceProposalStatus.readyForReview &&
            this.work.isNotEmpty) ||
        ({
              PerformanceProposalStatus.needsData,
              PerformanceProposalStatus.needsCalibration,
            }.contains(status) &&
            this.requirements.isEmpty) ||
        this.work.map((w) => w.id).toSet().length != this.work.length ||
        this.work.any((w) => !w.goalIds.contains(goal.id))) {
      throw ArgumentError('Estado y contenido de propuesta incompatibles.');
    }
  }
  final PerformanceTrainingGoal goal;
  final PerformanceProposalStatus status;
  final PerformancePolicyStage policyStage;
  final String? policyVersion;
  final List<String> reasons;
  final List<PerformanceDataRequirement> requirements;
  final List<PerformanceProposedWork> work;
}

/// Reúne cobertura y propuestas antes de coordinar. No genera una semana.
class PerformancePreparationPreview {
  PerformancePreparationPreview({
    required Iterable<PerformanceTrainingGoal> goals,
    required Iterable<PerformanceModuleProposal> proposals,
  }) : goals = List.unmodifiable(goals) {
    if (this.goals.isEmpty ||
        this.goals.map((g) => g.id).toSet().length != this.goals.length) {
      throw ArgumentError('La preparación necesita objetivos distintos.');
    }
    final expected = {for (final goal in this.goals) goal.id: goal};
    final byGoal = <String, PerformanceModuleProposal>{};
    for (final proposal in proposals) {
      if (expected[proposal.goal.id] != proposal.goal ||
          byGoal.containsKey(proposal.goal.id)) {
        throw ArgumentError('Propuesta duplicada, ajena o de otro protocolo.');
      }
      byGoal[proposal.goal.id] = proposal;
    }
    // Un objetivo sin estrategia permanece visible; nunca se omite para aparentar cobertura.
    this.proposals = List.unmodifiable([
      for (final goal in this.goals)
        byGoal[goal.id] ??
            PerformanceModuleProposal(
              goal: goal,
              status: PerformanceProposalStatus.unsupported,
              policyStage: PerformancePolicyStage.unavailable,
              reasons: const ['policy_not_available'],
            ),
    ]);
    final uniqueWork = <String, PerformanceProposedWork>{};
    for (final proposal in this.proposals) {
      for (final item in proposal.work) {
        if (!expected.keys.toSet().containsAll(item.goalIds) ||
            (uniqueWork.containsKey(item.id) && uniqueWork[item.id] != item)) {
          throw ArgumentError(
            'Trabajo compartido contradictorio o de un objetivo ajeno.',
          );
        }
        uniqueWork[item.id] = item;
      }
    }
    work = List.unmodifiable(uniqueWork.values);
  }

  final List<PerformanceTrainingGoal> goals;
  late final List<PerformanceModuleProposal> proposals;
  late final List<PerformanceProposedWork> work;
  bool get allGoalsReadyForReview => proposals.every(
    (p) => p.status == PerformanceProposalStatus.readyForReview,
  );
  bool get hasExperimentalPolicies => proposals.any(
    (p) => p.policyStage == PerformancePolicyStage.experimental,
  );
  List<PerformanceModuleProposal> get pending => List.unmodifiable(
    proposals.where(
      (p) => p.status != PerformanceProposalStatus.readyForReview,
    ),
  );
  List<PerformanceQuestionBlock> get questionBlocks =>
      List.unmodifiable(goals.map((g) => g.questionBlock).toSet());
  List<PerformanceDataRequirement> get requirements =>
      List.unmodifiable(proposals.expand((p) => p.requirements).toSet());
}

void _checkText(String value) {
  if (value.trim().isEmpty || value != value.trim()) {
    throw ArgumentError('Identidad o motivo vacío/no normalizado.');
  }
}
