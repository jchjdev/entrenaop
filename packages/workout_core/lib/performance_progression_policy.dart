import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart' show StrengthTask;

enum PerformanceProgressionModel { repetitions, loadAndRepetitions, duration }

enum PerformanceProgressionAction { establish, progress, maintain, reduce }

enum PerformanceExecutionStop { none, time, difficulty, unknown }

/// Trabajo submáximo ya calibrado; no convierte una marca de examen en dosis.
class PerformanceProgressionDose extends PerformanceWorkPrescription {
  PerformanceProgressionDose({
    required this.task,
    required this.model,
    required this.loadMode,
    required Iterable<int> targets,
    required this.restSeconds,
    this.loadKg,
    this.bodyMassKg,
    this.targetRir,
    this.policyVersion = PerformanceProgressionPolicy.version,
  }) : targets = List.unmodifiable(targets) {
    final measurement = switch (model) {
      PerformanceProgressionModel.repetitions => StrengthMeasurement.reps,
      PerformanceProgressionModel.loadAndRepetitions =>
        StrengthMeasurement.loadReps,
      PerformanceProgressionModel.duration => StrengthMeasurement.duration,
    };
    if (task.measurement != measurement ||
        this.targets.isEmpty ||
        this.targets.any((n) => n < 1) ||
        restSeconds < 0 ||
        (bodyMassKg != null && (!bodyMassKg!.isFinite || bodyMassKg! <= 0)) ||
        (loadMode == StrengthLoadMode.bodyweightPlusExternal &&
            bodyMassKg == null) ||
        policyVersion.trim().isEmpty ||
        (model == PerformanceProgressionModel.duration && targetRir != null) ||
        (model != PerformanceProgressionModel.duration &&
            (targetRir == null ||
                !targetRir!.isFinite ||
                targetRir! < 0 ||
                targetRir! > 10)) ||
        (model == PerformanceProgressionModel.loadAndRepetitions
            ? (loadKg == null ||
                  !loadKg!.isFinite ||
                  loadKg! <= 0 ||
                  !{
                    StrengthLoadMode.externalLoad,
                    StrengthLoadMode.bodyweightPlusExternal,
                  }.contains(loadMode))
            : (loadKg != null || loadMode != StrengthLoadMode.bodyweight))) {
      throw ArgumentError('Dosis calibrada incompatible con su modelo.');
    }
  }

  @override
  final StrengthTask task;
  final PerformanceProgressionModel model;
  final StrengthLoadMode loadMode;
  final List<int> targets;
  final int restSeconds;
  final double? loadKg;

  /// Masa corporal separada del lastre; un cambio rompe la comparabilidad.
  final double? bodyMassKg;
  final double? targetRir;
  final String policyVersion;

  // Reserva provisional de revisión: calentamiento y margen de ejecución.
  // No prescribe cinco segundos por repetición ni coordina sesiones completas.
  @override
  int get estimatedSeconds =>
      300 +
      targets.fold<int>(0, (total, n) => total + n) *
          (model == PerformanceProgressionModel.duration ? 1 : 5) +
      (targets.length - 1) * restSeconds;

  PerformanceProgressionDose withTargets(
    List<int> values, {
    double? nextLoad,
  }) => PerformanceProgressionDose(
    task: task,
    model: model,
    loadMode: loadMode,
    targets: values,
    restSeconds: restSeconds,
    loadKg: nextLoad ?? loadKg,
    bodyMassKg: bodyMassKg,
    targetRir: targetRir,
    policyVersion: policyVersion,
  );

  @override
  List<Object?> get props => [
    task,
    model,
    loadMode,
    targets,
    restSeconds,
    loadKg,
    bodyMassKg,
    targetRir,
    policyVersion,
  ];
}

class PerformanceProgressionSet {
  PerformanceProgressionSet({
    this.validUnits,
    this.techniqueValid,
    this.rir,
    this.actualLoadKg,
  }) {
    if ((validUnits != null && validUnits! < 0) ||
        (rir != null && (!rir!.isFinite || rir! < 0 || rir! > 10)) ||
        (actualLoadKg != null &&
            (!actualLoadKg!.isFinite || actualLoadKg! <= 0))) {
      throw ArgumentError('Resultado de serie no válido.');
    }
  }
  final int? validUnits;
  final bool? techniqueValid;
  final double? rir;
  final double? actualLoadKg;
}

class PerformanceProgressionExposure {
  PerformanceProgressionExposure({
    required this.id,
    required this.performedOn,
    required this.dose,
    required Iterable<PerformanceProgressionSet> sets,
    required this.tolerated,
    this.conditionsConfirmed,
    this.actualBodyMassKg,
    this.stop = PerformanceExecutionStop.unknown,
  }) : sets = List.unmodifiable(sets) {
    if (id.trim().isEmpty ||
        this.sets.length > dose.targets.length ||
        (dose.model == PerformanceProgressionModel.duration &&
            this.sets.any((s) => s.rir != null)) ||
        (dose.model != PerformanceProgressionModel.loadAndRepetitions &&
            this.sets.any((s) => s.actualLoadKg != null)) ||
        (actualBodyMassKg != null &&
            (!actualBodyMassKg!.isFinite || actualBodyMassKg! <= 0))) {
      throw ArgumentError('Ejecución incompatible con la dosis.');
    }
  }
  final String id;
  final DateTime performedOn;
  final PerformanceProgressionDose dose;
  final List<PerformanceProgressionSet> sets;
  final bool? tolerated;
  final PerformanceExecutionStop stop;

  /// Declaración de que se mantuvieron variante, montaje y descansos.
  final bool? conditionsConfirmed;
  final double? actualBodyMassKg;
}

/// Parámetros operativos experimentales, explícitos y versionados (STR-011).
class PerformanceProgressionRules {
  PerformanceProgressionRules({
    this.durationStepSeconds = 2,
    this.minimumRepetitions = 4,
    this.maximumRepetitions = 6,
    this.loadStepKg = 2.5,
  }) {
    if (durationStepSeconds < 1 ||
        minimumRepetitions < 1 ||
        maximumRepetitions <= minimumRepetitions ||
        !loadStepKg.isFinite ||
        loadStepKg <= 0) {
      throw ArgumentError('Escalones de progresión no válidos.');
    }
  }
  final int durationStepSeconds;
  final int minimumRepetitions;
  final int maximumRepetitions;
  final double loadStepKg;
}

class PerformanceProgressionDecision {
  const PerformanceProgressionDecision({
    required this.proposal,
    required this.rules,
    this.action,
    this.dose,
  });
  final PerformanceModuleProposal proposal;
  final PerformanceProgressionRules rules;
  final PerformanceProgressionAction? action;
  final PerformanceProgressionDose? dose;
}

/// Revisa una exposición; no selecciona días, fases ni publica una semana.
class PerformanceProgressionPolicy {
  static const version = 'performance_progression_draft_v2';

  PerformanceProgressionDecision preview({
    required PerformanceTrainingGoal goal,
    required Iterable<StrengthExerciseDefinition> catalog,
    required Set<String> equipment,
    required PerformanceProgressionDose calibratedDose,
    required DateTime calibratedOn,
    required DateTime now,
    required bool currentCapacityConfirmed,
    required bool hasSymptoms,
    Iterable<PerformanceProgressionExposure> history = const [],
    int preferredDay = 0,
    PerformanceProgressionRules? rules,
  }) {
    final settings = rules ?? PerformanceProgressionRules();
    PerformanceProgressionDecision pending(
      PerformanceProposalStatus status,
      String reason, {
      bool calibration = false,
    }) => PerformanceProgressionDecision(
      rules: settings,
      proposal: PerformanceModuleProposal(
        goal: goal,
        status: status,
        policyStage: PerformancePolicyStage.experimental,
        policyVersion: version,
        reasons: [reason],
        requirements:
            {
              PerformanceProposalStatus.needsData,
              PerformanceProposalStatus.needsCalibration,
            }.contains(status)
            ? [
                PerformanceDataRequirement(
                  key: calibration ? 'working_reference' : 'current_context',
                  task: calibration ? calibratedDose.task : null,
                  reason: reason,
                ),
              ]
            : const [],
      ),
    );
    if (hasSymptoms) {
      return pending(
        PerformanceProposalStatus.blocked,
        'symptoms_or_limitation',
      );
    }
    if (!currentCapacityConfirmed) {
      return pending(
        PerformanceProposalStatus.needsData,
        'confirm_current_capacity',
      );
    }
    final workDefinition = catalog.where(
      (e) =>
          e.code == calibratedDose.task.exerciseCode &&
          e.definitionVersion == calibratedDose.task.exerciseVersion,
    );
    final expectedCapability = switch (calibratedDose.model) {
      PerformanceProgressionModel.repetitions =>
        PerformanceCapability.repetitions,
      PerformanceProgressionModel.loadAndRepetitions =>
        PerformanceCapability.maximalStrength,
      PerformanceProgressionModel.duration =>
        PerformanceCapability.isometricEndurance,
    };
    // Solo práctica de la misma variante. Los apoyos necesitan relaciones revisadas.
    if (goal.capability != expectedCapability ||
        goal.loadMode != calibratedDose.loadMode ||
        calibratedDose.policyVersion != version ||
        goal.task.exerciseCode != calibratedDose.task.exerciseCode ||
        goal.task.exerciseVersion != calibratedDose.task.exerciseVersion ||
        goal.task.setupKey != calibratedDose.task.setupKey ||
        (calibratedDose.model !=
                PerformanceProgressionModel.loadAndRepetitions &&
            goal.task != calibratedDose.task) ||
        workDefinition.length != 1 ||
        !goal.isRepresentedBy(workDefinition.single) ||
        (calibratedDose.model == PerformanceProgressionModel.repetitions &&
            (!workDefinition.single.movementModes.contains('dynamic') ||
                workDefinition.single.movementModes.contains('plyometric'))) ||
        !workDefinition.single.supports(
          calibratedDose.task.measurement,
          calibratedDose.loadMode,
        )) {
      return pending(
        PerformanceProposalStatus.unsupported,
        'task_or_model_not_covered',
      );
    }
    if (!workDefinition.single.hasRequiredEquipment(equipment)) {
      return pending(
        PerformanceProposalStatus.needsData,
        'required_equipment_missing',
      );
    }
    if (calibratedOn.isAfter(now) ||
        calibratedOn.isBefore(now.subtract(const Duration(days: 14))) ||
        (calibratedDose.targetRir != null &&
            (calibratedDose.targetRir! < 2 || calibratedDose.targetRir! > 4)) ||
        (calibratedDose.model ==
                PerformanceProgressionModel.loadAndRepetitions &&
            calibratedDose.targets.any(
              (n) =>
                  n < settings.minimumRepetitions ||
                  n > settings.maximumRepetitions,
            ))) {
      return pending(
        PerformanceProposalStatus.needsCalibration,
        'update_comparable_working_reference',
        calibration: true,
      );
    }
    final observations = history.toList();
    if (observations.map((e) => e.id).toSet().length != observations.length) {
      throw ArgumentError('Una ejecución no puede contarse dos veces.');
    }
    if (observations.any((e) => e.performedOn.isAfter(now))) {
      return pending(
        PerformanceProposalStatus.needsData,
        'execution_date_in_future',
      );
    }
    observations.sort((a, b) {
      final date = b.performedOn.compareTo(a.performedOn);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    final days = <DateTime>{};
    final recent = observations
        .where((e) {
          final date = e.performedOn.toUtc();
          return !date.isBefore(
                now.toUtc().subtract(const Duration(days: 14)),
              ) &&
              !date.isBefore(calibratedOn.toUtc()) &&
              days.add(DateTime.utc(date.year, date.month, date.day));
        })
        .take(2)
        .toList();
    var action = PerformanceProgressionAction.maintain;
    var reason = 'two_comparable_exposures_needed';
    var nextDose = calibratedDose;
    if (observations.isEmpty) {
      action = PerformanceProgressionAction.establish;
      reason = 'use_confirmed_working_dose';
    } else if (recent.length == 2) {
      if (recent.any((e) => e.dose != calibratedDose)) {
        reason = 'latest_doses_not_comparable';
      } else if (recent.any((e) => e.conditionsConfirmed != true)) {
        reason = 'execution_conditions_not_confirmed';
      } else if (calibratedDose.model ==
              PerformanceProgressionModel.loadAndRepetitions &&
          recent.any(
            (e) =>
                e.sets.isEmpty ||
                e.sets.any((s) => s.actualLoadKg != calibratedDose.loadKg) ||
                (calibratedDose.loadMode ==
                        StrengthLoadMode.bodyweightPlusExternal &&
                    e.actualBodyMassKg != calibratedDose.bodyMassKg),
          )) {
        reason = 'actual_load_not_comparable';
      } else if (recent.every(_successful)) {
        nextDose = _progress(calibratedDose, settings);
        action = PerformanceProgressionAction.progress;
        reason =
            calibratedDose.model ==
                    PerformanceProgressionModel.loadAndRepetitions &&
                nextDose.loadKg != calibratedDose.loadKg
            ? 'consolidated_range_increase_load'
            : 'two_tolerated_exposures_increase_one_target';
      } else if (recent.every(_difficult)) {
        final reduced = _reduce(calibratedDose, settings);
        if (reduced == null) {
          return pending(
            PerformanceProposalStatus.needsCalibration,
            'difficulty_at_minimum_update_reference',
            calibration: true,
          );
        }
        nextDose = reduced;
        action = PerformanceProgressionAction.reduce;
        reason = 'repeated_difficulty_reduce_one_target';
      } else {
        reason = 'mixed_incomplete_or_time_limited_response';
      }
    }
    return PerformanceProgressionDecision(
      rules: settings,
      dose: nextDose,
      action: action,
      proposal: PerformanceModuleProposal(
        goal: goal,
        status: PerformanceProposalStatus.readyForReview,
        policyStage: PerformancePolicyStage.experimental,
        policyVersion: version,
        reasons: [reason],
        work: [
          PerformanceProposedWork(
            id: '${goal.id}:progression:$preferredDay',
            goalIds: {goal.id},
            prescription: nextDose,
            preferredDay: preferredDay,
          ),
        ],
      ),
    );
  }

  bool _successful(PerformanceProgressionExposure e) {
    if (e.stop != PerformanceExecutionStop.none ||
        e.tolerated != true ||
        e.sets.length != e.dose.targets.length) {
      return false;
    }
    for (var i = 0; i < e.sets.length; i++) {
      final s = e.sets[i];
      if (s.techniqueValid != true ||
          s.validUnits == null ||
          s.validUnits! < e.dose.targets[i] ||
          (e.dose.targetRir != null &&
              (s.rir == null || s.rir! < e.dose.targetRir!))) {
        return false;
      }
    }
    return true;
  }

  bool _difficult(PerformanceProgressionExposure e) {
    if (e.stop == PerformanceExecutionStop.difficulty ||
        e.tolerated == false ||
        e.sets.any(
          (s) =>
              s.techniqueValid == false ||
              (e.dose.targetRir != null && s.rir != null && s.rir! < 2),
        )) {
      return true;
    }
    if (e.stop != PerformanceExecutionStop.none) return false;
    for (var i = 0; i < e.sets.length; i++) {
      final units = e.sets[i].validUnits;
      if (units != null && units < e.dose.targets[i]) return true;
    }
    return false;
  }

  PerformanceProgressionDose _progress(
    PerformanceProgressionDose dose,
    PerformanceProgressionRules rules,
  ) {
    if (dose.model == PerformanceProgressionModel.loadAndRepetitions &&
        dose.targets.every((n) => n == rules.maximumRepetitions)) {
      return dose.withTargets(
        List.filled(dose.targets.length, rules.minimumRepetitions),
        nextLoad: dose.loadKg! + rules.loadStepKg,
      );
    }
    final targets = dose.targets.toList();
    final smallest = targets.reduce((a, b) => a < b ? a : b);
    final index = targets.indexOf(smallest);
    targets[index] += dose.model == PerformanceProgressionModel.duration
        ? rules.durationStepSeconds
        : 1;
    return dose.withTargets(targets);
  }

  PerformanceProgressionDose? _reduce(
    PerformanceProgressionDose dose,
    PerformanceProgressionRules rules,
  ) {
    final targets = dose.targets.toList();
    final largest = targets.reduce((a, b) => a > b ? a : b);
    final floor = dose.model == PerformanceProgressionModel.loadAndRepetitions
        ? rules.minimumRepetitions
        : 1;
    if (largest <= floor) return null;
    final step = dose.model == PerformanceProgressionModel.duration
        ? rules.durationStepSeconds
        : 1;
    targets[targets.lastIndexOf(largest)] = (largest - step).clamp(
      floor,
      largest,
    );
    return dose.withTargets(targets);
  }
}
