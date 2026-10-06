import 'package:equatable/equatable.dart';
import 'package:workout_core/strength_exercise_catalog.dart';

/// Identidad de una tarea revisada. No interpreta nombres de pruebas o baremos.
class StrengthTask extends Equatable {
  StrengthTask({
    required this.exerciseCode,
    required this.exerciseVersion,
    required this.protocolKey,
    required this.protocolVersion,
    required this.setupKey,
    required this.measurement,
  }) {
    if (exerciseCode.trim().isEmpty ||
        protocolKey.trim().isEmpty ||
        setupKey.trim().isEmpty ||
        exerciseVersion < 1 ||
        protocolVersion < 1) {
      throw ArgumentError('La tarea necesita variante, protocolo y montaje.');
    }
  }
  final String exerciseCode;
  final int exerciseVersion;
  final String protocolKey;
  final int protocolVersion;
  final String setupKey;
  final StrengthMeasurement measurement;
  @override
  List<Object?> get props => [
    exerciseCode,
    exerciseVersion,
    protocolKey,
    protocolVersion,
    setupKey,
    measurement,
  ];
}

class StrengthWorkingReference {
  StrengthWorkingReference({
    required this.task,
    required this.validReps,
    required this.reportedRir,
    required this.observedOn,
    required this.currentCapacityConfirmed,
  }) {
    if (validReps < 1 ||
        !reportedRir.isFinite ||
        reportedRir < 0 ||
        reportedRir > 10) {
      throw ArgumentError('Referencia de trabajo no válida.');
    }
  }
  final StrengthTask task;
  final int validReps;
  final double reportedRir;
  final DateTime observedOn;
  final bool currentCapacityConfirmed;
}

/// Tiempo disponible después de reservar las demás tareas de la preparación.
class StrengthDaySlot {
  StrengthDaySlot({
    required this.day,
    required this.availableSeconds,
    this.reservedSeconds = 0,
    this.pushWorkReserved = false,
  }) {
    if (day < 0 ||
        day > 6 ||
        availableSeconds < 0 ||
        reservedSeconds < 0 ||
        reservedSeconds > availableSeconds) {
      throw ArgumentError('Disponibilidad semanal no válida.');
    }
  }
  final int day;
  final int availableSeconds;
  final int reservedSeconds;
  final bool pushWorkReserved;
  int get remainingSeconds => availableSeconds - reservedSeconds;
}

class StrengthWorkPrescription extends Equatable {
  StrengthWorkPrescription({
    required this.policyVersion,
    required this.goal,
    required this.task,
    required this.setCount,
    required this.repsPerSet,
    required this.targetRir,
    required this.restSeconds,
  }) {
    if (policyVersion.trim().isEmpty ||
        setCount < 1 ||
        repsPerSet < 1 ||
        !targetRir.isFinite ||
        targetRir < 0 ||
        targetRir > 10 ||
        restSeconds < 0 ||
        task.measurement != StrengthMeasurement.reps) {
      throw ArgumentError('Prescripción de repeticiones no válida.');
    }
  }
  final String policyVersion;
  final StrengthTask goal;
  final StrengthTask task;
  final int setCount;
  final int repsPerSet;
  final double targetRir;
  final int restSeconds;
  // Margen de agenda provisional; no prescribe un tempo de cinco segundos.
  int get estimatedSeconds =>
      300 + setCount * repsPerSet * 5 + (setCount - 1) * restSeconds;
  @override
  List<Object?> get props => [
    policyVersion,
    goal,
    task,
    setCount,
    repsPerSet,
    targetRir,
    restSeconds,
  ];
}

enum StrengthInterruption { none, time, difficulty, unknown }

class StrengthSetObservation {
  StrengthSetObservation({
    required this.validReps,
    required this.techniqueValid,
    this.reportedRir,
  }) {
    if (validReps < 0 ||
        (reportedRir != null &&
            (!reportedRir!.isFinite ||
                reportedRir! < 0 ||
                reportedRir! > 10))) {
      throw ArgumentError('Resultado de serie no válido.');
    }
  }
  final int validReps;
  final bool techniqueValid;
  final double? reportedRir;
}

class StrengthExposure {
  StrengthExposure({
    required this.id,
    required this.performedOn,
    required this.prescription,
    required Iterable<StrengthSetObservation> sets,
    this.interruption = StrengthInterruption.none,
  }) : sets = List.unmodifiable(sets) {
    if (id.trim().isEmpty || this.sets.length > prescription.setCount) {
      throw ArgumentError('Exposición no válida.');
    }
  }
  final String id;
  final DateTime performedOn;
  final StrengthWorkPrescription prescription;
  final List<StrengthSetObservation> sets;
  final StrengthInterruption interruption;
}

enum StrengthDecisionStatus {
  ready,
  needsContext,
  needsCalibration,
  blocked,
  unsupported,
  noSpace,
}

enum StrengthDoseAction { initial, hold, progress, reduce }

enum StrengthDecisionReason {
  symptoms,
  contextMissing,
  unsupportedGoal,
  calibrationMissing,
  specificPractice,
  accessibleSupport,
  initialDose,
  comparableHistoryMissing,
  twoToleratedExposures,
  twoDifficultExposures,
  responseUnclear,
  oneExposureOnly,
  recalibrationRequired,
  agendaLimited,
  noAvailableSlot,
}

class StrengthScheduledWork {
  const StrengthScheduledWork({required this.day, required this.prescription});
  final int day;
  final StrengthWorkPrescription prescription;
}

class StrengthTrainingDecision {
  StrengthTrainingDecision({
    required this.status,
    required this.action,
    required Iterable<StrengthDecisionReason> reasons,
    Iterable<StrengthScheduledWork> sessions = const [],
  }) : reasons = List.unmodifiable(reasons),
       sessions = List.unmodifiable(sessions);
  final StrengthDecisionStatus status;
  final StrengthDoseAction action;
  final List<StrengthDecisionReason> reasons;
  final List<StrengthScheduledWork> sessions;
}

/// Hipótesis deportiva para revisión en ADMIN, aún sin publicación automática.
/// Las constantes de dosis son política de producto, no leyes fisiológicas.
class PushUpRepetitionsPolicy {
  static const version = 'push_up_reps_draft_v1';

  StrengthTrainingDecision preview({
    required StrengthTask goal,
    required Iterable<StrengthExerciseDefinition> catalog,
    required Set<String> equipment,
    required Iterable<StrengthWorkingReference> references,
    required Iterable<StrengthDaySlot> slots,
    required DateTime now,
    required bool currentContextConfirmed,
    required bool hasSymptoms,
    StrengthWorkPrescription? previousPrescription,
    Iterable<StrengthExposure> history = const [],
  }) {
    StrengthTrainingDecision stop(
      StrengthDecisionStatus status,
      StrengthDecisionReason reason,
    ) => StrengthTrainingDecision(
      status: status,
      action: StrengthDoseAction.hold,
      reasons: [reason],
    );
    if (hasSymptoms) {
      return stop(
        StrengthDecisionStatus.blocked,
        StrengthDecisionReason.symptoms,
      );
    }
    if (!currentContextConfirmed) {
      return stop(
        StrengthDecisionStatus.needsContext,
        StrengthDecisionReason.contextMissing,
      );
    }
    if (goal.exerciseCode != 'push_up_standard' ||
        goal.measurement != StrengthMeasurement.reps) {
      return stop(
        StrengthDecisionStatus.unsupported,
        StrengthDecisionReason.unsupportedGoal,
      );
    }
    final definitions = catalog.toList();
    if (definitions
            .map((e) => '${e.code}:${e.definitionVersion}')
            .toSet()
            .length !=
        definitions.length) {
      throw ArgumentError('Catálogo duplicado.');
    }
    final goalDefinitions = definitions.where(
      (e) =>
          e.code == goal.exerciseCode &&
          e.definitionVersion == goal.exerciseVersion,
    );
    if (goalDefinitions.isEmpty) {
      return stop(
        StrengthDecisionStatus.unsupported,
        StrengthDecisionReason.unsupportedGoal,
      );
    }
    final days = slots.toList()..sort((a, b) => a.day.compareTo(b.day));
    if (days.map((s) => s.day).toSet().length != days.length) {
      throw ArgumentError('Hay días repetidos.');
    }
    // Prioridad específica; la inclinada es apoyo, nunca marca equivalente.
    final candidates =
        references.where((reference) {
          if (!reference.currentCapacityConfirmed ||
              reference.observedOn.isAfter(now) ||
              reference.reportedRir < 2 ||
              reference.reportedRir > 4 ||
              reference.task.measurement != StrengthMeasurement.reps) {
            return false;
          }
          if (reference.task.exerciseCode == 'push_up_standard') {
            if (reference.task != goal) return false;
          } else if (reference.task.exerciseCode != 'push_up_incline') {
            return false;
          }
          return definitions.any(
            (definition) =>
                definition.code == reference.task.exerciseCode &&
                definition.definitionVersion ==
                    reference.task.exerciseVersion &&
                definition.measurements.any(
                  (m) =>
                      m.mode == StrengthMeasurement.reps &&
                      m.supports(StrengthLoadMode.bodyweight),
                ) &&
                definition.requiredEquipment.every(equipment.contains),
          );
        }).toList()..sort((a, b) {
          final specificA = a.task == goal ? 0 : 1;
          final specificB = b.task == goal ? 0 : 1;
          final priority = specificA.compareTo(specificB);
          return priority != 0
              ? priority
              : b.observedOn.compareTo(a.observedOn);
        });
    if (candidates.isEmpty) {
      return stop(
        StrengthDecisionStatus.needsCalibration,
        StrengthDecisionReason.calibrationMissing,
      );
    }
    final reference = candidates.first;
    if (candidates
        .skip(1)
        .any(
          (candidate) =>
              candidate.task == reference.task &&
              candidate.observedOn == reference.observedOn &&
              (candidate.validReps != reference.validReps ||
                  candidate.reportedRir != reference.reportedRir),
        )) {
      return stop(
        StrengthDecisionStatus.needsCalibration,
        StrengthDecisionReason.calibrationMissing,
      );
    }
    final reasons = <StrengthDecisionReason>[
      reference.task == goal
          ? StrengthDecisionReason.specificPractice
          : StrengthDecisionReason.accessibleSupport,
    ];
    var action = StrengthDoseAction.initial;
    var reps = reference.validReps;
    var setCount = 2;
    if (previousPrescription != null) {
      if (previousPrescription.policyVersion != version ||
          previousPrescription.goal != goal ||
          previousPrescription.task != reference.task ||
          previousPrescription.setCount != 2 ||
          previousPrescription.repsPerSet < 1 ||
          previousPrescription.targetRir != 3 ||
          previousPrescription.restSeconds != 120) {
        return stop(
          StrengthDecisionStatus.needsCalibration,
          StrengthDecisionReason.recalibrationRequired,
        );
      }
      reps = previousPrescription.repsPerSet;
      setCount = previousPrescription.setCount;
      action = StrengthDoseAction.hold;
      final exposures = history.toList();
      if (exposures.map((e) => e.id).toSet().length != exposures.length) {
        throw ArgumentError('Una ejecución no puede contabilizarse dos veces.');
      }
      final comparable =
          exposures
              .where(
                (e) =>
                    !e.performedOn.isAfter(now) &&
                    e.prescription == previousPrescription,
              )
              .toList()
            ..sort((a, b) => b.performedOn.compareTo(a.performedOn));
      if (comparable.isEmpty) {
        reasons.add(StrengthDecisionReason.comparableHistoryMissing);
      } else if (comparable.length < 2) {
        reasons.add(StrengthDecisionReason.oneExposureOnly);
      } else {
        final latest = comparable.take(2).toList();
        bool difficult(StrengthExposure e) =>
            e.interruption == StrengthInterruption.difficulty ||
            (e.interruption == StrengthInterruption.none &&
                e.sets.any(
                  (s) =>
                      !s.techniqueValid ||
                      (s.reportedRir != null && s.reportedRir! < 2),
                ));
        bool tolerated(StrengthExposure e) =>
            e.interruption == StrengthInterruption.none &&
            e.sets.length == setCount &&
            e.sets.every(
              (s) =>
                  s.techniqueValid &&
                  s.validReps >= reps &&
                  s.reportedRir != null &&
                  s.reportedRir! >= 3,
            );
        // Dos registros del mismo día no acreditan dos exposiciones separadas.
        final distinctDays =
            latest.first.performedOn.year != latest.last.performedOn.year ||
            latest.first.performedOn.month != latest.last.performedOn.month ||
            latest.first.performedOn.day != latest.last.performedOn.day;
        if (!distinctDays) {
          reasons.add(StrengthDecisionReason.responseUnclear);
        } else if (latest.every(difficult)) {
          if (reps == 1) {
            return stop(
              StrengthDecisionStatus.needsCalibration,
              StrengthDecisionReason.recalibrationRequired,
            );
          }
          reps -= 1;
          action = StrengthDoseAction.reduce;
          reasons.add(StrengthDecisionReason.twoDifficultExposures);
        } else if (latest.every(tolerated)) {
          reps += 1;
          action = StrengthDoseAction.progress;
          reasons.add(StrengthDecisionReason.twoToleratedExposures);
        } else {
          reasons.add(StrengthDecisionReason.responseUnclear);
        }
      }
    } else {
      reasons.add(StrengthDecisionReason.initialDose);
    }
    final prescription = StrengthWorkPrescription(
      policyVersion: version,
      goal: goal,
      task: reference.task,
      setCount: setCount,
      repsPerSet: reps,
      targetRir: 3,
      restSeconds: 120,
    );
    // Dos exposiciones como máximo, separadas también al repetir la semana.
    final eligible = days
        .where(
          (s) =>
              !s.pushWorkReserved &&
              s.remainingSeconds >= prescription.estimatedSeconds,
        )
        .toList();
    final chosen = <StrengthDaySlot>[];
    for (final first in eligible) {
      final second = eligible
          .where((s) => s.day - first.day >= 2 && s.day - first.day <= 5)
          .firstOrNull;
      if (second != null) {
        chosen.addAll([first, second]);
        break;
      }
    }
    if (chosen.isEmpty && eligible.isNotEmpty) chosen.add(eligible.first);
    if (chosen.isEmpty) {
      return stop(
        StrengthDecisionStatus.noSpace,
        StrengthDecisionReason.noAvailableSlot,
      );
    }
    if (chosen.length < 2) reasons.add(StrengthDecisionReason.agendaLimited);
    return StrengthTrainingDecision(
      status: StrengthDecisionStatus.ready,
      action: action,
      reasons: reasons,
      sessions: chosen.map(
        (s) => StrengthScheduledWork(day: s.day, prescription: prescription),
      ),
    );
  }
}
