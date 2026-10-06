import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_progression_policy.dart';
import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:workout_core/strength_training_policy.dart' show StrengthTask;

import 'strength_exercise_catalog_test.dart' show readCatalogJson;

void main() {
  final catalog = StrengthExerciseCatalogCodec.decode(readCatalogJson())
      .exercises;
  final now = DateTime.utc(2026, 10, 3);
  StrengthTask task(
    String code,
    StrengthMeasurement measurement, {
    int protocol = 1,
  }) => StrengthTask(
    exerciseCode: code,
    exerciseVersion: 1,
    protocolKey: '${code}_practice',
    protocolVersion: protocol,
    setupKey: 'fixed_setup',
    measurement: measurement,
  );
  PerformanceProgressionDose reps({
    String code = 'push_up_standard',
    List<int> targets = const [8, 8],
    int protocol = 1,
    String version = PerformanceProgressionPolicy.version,
  }) => PerformanceProgressionDose(
    task: task(code, StrengthMeasurement.reps, protocol: protocol),
    model: PerformanceProgressionModel.repetitions,
    loadMode: StrengthLoadMode.bodyweight,
    targets: targets,
    restSeconds: 120,
    targetRir: 3,
    policyVersion: version,
  );
  PerformanceProgressionDose duration({List<int> targets = const [20, 20]}) =>
      PerformanceProgressionDose(
        task: task('front_plank_forearms', StrengthMeasurement.duration),
        model: PerformanceProgressionModel.duration,
        loadMode: StrengthLoadMode.bodyweight,
        targets: targets,
        restSeconds: 60,
      );
  PerformanceProgressionDose load({List<int> targets = const [6, 6]}) =>
      PerformanceProgressionDose(
        task: task('bench_press_barbell', StrengthMeasurement.loadReps),
        model: PerformanceProgressionModel.loadAndRepetitions,
        loadMode: StrengthLoadMode.externalLoad,
        targets: targets,
        restSeconds: 120,
        targetRir: 3,
        loadKg: 40,
      );
  PerformanceTrainingGoal goal(
    PerformanceProgressionDose dose, {
    PerformanceCapability? capability,
  }) => PerformanceTrainingGoal(
    id: 'target',
    capability:
        capability ??
        switch (dose.model) {
          PerformanceProgressionModel.repetitions =>
            PerformanceCapability.repetitions,
          PerformanceProgressionModel.duration =>
            PerformanceCapability.isometricEndurance,
          PerformanceProgressionModel.loadAndRepetitions =>
            PerformanceCapability.maximalStrength,
        },
    questionBlock: PerformanceQuestionBlock.pushes,
    task: dose.model == PerformanceProgressionModel.loadAndRepetitions
        ? task(dose.task.exerciseCode, StrengthMeasurement.maxLoad)
        : dose.task,
    loadMode: dose.loadMode,
  );
  PerformanceProgressionExposure exposure(
    PerformanceProgressionDose dose,
    int age, {
    bool? tolerated = true,
    double? rir = 3,
    bool? technique = true,
    PerformanceExecutionStop stop = PerformanceExecutionStop.none,
    List<int>? units,
    bool missing = false,
    bool? conditionsConfirmed = true,
    bool missingLoad = false,
    double? actualLoadKg,
    String? id,
  }) => PerformanceProgressionExposure(
    id: id ?? 'exposure_$age',
    performedOn: now.subtract(Duration(days: age)),
    dose: dose,
    tolerated: tolerated,
    stop: stop,
    conditionsConfirmed: conditionsConfirmed,
    actualBodyMassKg: dose.bodyMassKg,
    sets: [
      for (var i = 0; i < dose.targets.length; i++)
        PerformanceProgressionSet(
          validUnits: missing ? null : units?[i] ?? dose.targets[i],
          techniqueValid: technique,
          rir: dose.model == PerformanceProgressionModel.duration ? null : rir,
          actualLoadKg: missingLoad ? null : actualLoadKg ?? dose.loadKg,
        ),
    ],
  );
  PerformanceProgressionDecision evaluate(
    PerformanceProgressionDose dose, {
    Iterable<PerformanceProgressionExposure> history = const [],
    bool confirmed = true,
    bool symptoms = false,
    Set<String>? equipment,
    DateTime? calibratedOn,
    PerformanceTrainingGoal? target,
  }) => PerformanceProgressionPolicy().preview(
    goal: target ?? goal(dose),
    catalog: catalog,
    equipment: equipment ?? catalog.expand((p) => p.requiredEquipment).toSet(),
    calibratedDose: dose,
    calibratedOn: calibratedOn ?? now.subtract(const Duration(days: 7)),
    now: now,
    currentCapacityConfirmed: confirmed,
    hasSymptoms: symptoms,
    history: history,
  );

  test(
    'establece dosis calibradas de flexiones, dominadas, banca e isometría',
    () {
      for (final dose in [
        reps(),
        reps(code: 'pull_up_pronated', targets: [4, 4]),
        load(),
        duration(),
      ]) {
        final decision = evaluate(dose);
        expect(decision.dose, dose);
        expect(decision.action, PerformanceProgressionAction.establish);
        expect(
          decision.proposal.status,
          PerformanceProposalStatus.readyForReview,
        );
        expect(
          decision.proposal.policyStage,
          PerformancePolicyStage.experimental,
        );
      }
    },
  );

  test(
    'progresa una repetición total y equilibra series sin cambiar descansos',
    () {
      final dose = reps(targets: [9, 8]);
      final result = evaluate(
        dose,
        history: [exposure(dose, 2), exposure(dose, 5)],
      );
      expect(result.dose!.targets, [9, 9]);
      expect(result.dose!.restSeconds, dose.restSeconds);
      expect(result.dose!.targetRir, dose.targetRir);
      expect(result.action, PerformanceProgressionAction.progress);
    },
  );

  test(
    'doble progresión sube carga solo tras consolidar toda la horquilla',
    () {
      final full = load();
      final up = evaluate(
        full,
        history: [exposure(full, 2), exposure(full, 5)],
      );
      expect(up.dose!.loadKg, 42.5);
      expect(up.dose!.targets, [4, 4]);
      final partial = load(targets: [6, 5]);
      final next = evaluate(
        partial,
        history: [exposure(partial, 2), exposure(partial, 5)],
      );
      expect(next.dose!.loadKg, 40);
      expect(next.dose!.targets, [6, 6]);
      expect(up.rules.loadStepKg, 2.5);
    },
  );

  test(
    'no consolida kilos cambiados o desconocidos ni condiciones ausentes',
    () {
      final dose = load();
      for (final history in [
        [exposure(dose, 2, actualLoadKg: 35), exposure(dose, 5)],
        [exposure(dose, 2, missingLoad: true), exposure(dose, 5)],
        [
          exposure(dose, 2, actualLoadKg: 35, rir: 1, tolerated: false),
          exposure(dose, 5, actualLoadKg: 35, rir: 1, tolerated: false),
        ],
      ]) {
        final result = evaluate(dose, history: history);
        expect(result.action, PerformanceProgressionAction.maintain);
        expect(result.proposal.reasons, ['actual_load_not_comparable']);
        expect(result.dose, dose);
      }
      for (final confirmed in [null, false]) {
        final result = evaluate(
          reps(),
          history: [
            exposure(reps(), 2, conditionsConfirmed: confirmed),
            exposure(reps(), 5),
          ],
        );
        expect(result.action, PerformanceProgressionAction.maintain);
        expect(result.proposal.reasons, ['execution_conditions_not_confirmed']);
      }
      expect(
        () => PerformanceProgressionSet(actualLoadKg: double.nan),
        throwsArgumentError,
      );
    },
  );

  test(
    'no declarar interrupción no equivale a completarla sin interrupción',
    () {
      final dose = reps();
      final history = [
        for (final age in [2, 5])
          PerformanceProgressionExposure(
            id: 'unknown_$age',
            performedOn: now.subtract(Duration(days: age)),
            dose: dose,
            sets: exposure(dose, age).sets,
            tolerated: true,
            conditionsConfirmed: true,
          ),
      ];
      expect(history.first.stop, PerformanceExecutionStop.unknown);
      expect(
        evaluate(dose, history: history).action,
        PerformanceProgressionAction.maintain,
      );
    },
  );

  test('la v2 no reinterpreta referencias ni registros de v1', () {
    final oldDose = reps(version: 'performance_progression_draft_v1');
    expect(
      evaluate(oldDose).proposal.status,
      PerformanceProposalStatus.unsupported,
    );
    final decision = evaluate(
      reps(),
      history: [exposure(oldDose, 2), exposure(oldDose, 5)],
    );
    expect(decision.action, PerformanceProgressionAction.maintain);
    expect(decision.proposal.reasons, ['latest_doses_not_comparable']);
  });

  test('progresa segundos sin inventar RIR isométrico', () {
    final dose = duration();
    final result = evaluate(
      dose,
      history: [exposure(dose, 2), exposure(dose, 5)],
    );
    expect(result.dose!.targets, [22, 20]);
    expect(result.dose!.targetRir, isNull);
    expect(
      () => PerformanceProgressionExposure(
        id: 'invalid',
        performedOn: now,
        dose: dose,
        sets: [PerformanceProgressionSet(validUnits: 20, rir: 3)],
        tolerated: true,
      ),
      throwsArgumentError,
    );
  });

  test(
    'datos incompletos, una exposición, omisión y tiempo mantienen dosis',
    () {
      final dose = reps();
      final histories = [
        [exposure(dose, 2)],
        [exposure(dose, 2, missing: true), exposure(dose, 5, missing: true)],
        [exposure(dose, 2, rir: null), exposure(dose, 5, rir: null)],
        [
          exposure(dose, 2, tolerated: null),
          exposure(dose, 5, tolerated: null),
        ],
        [
          exposure(dose, 2, stop: PerformanceExecutionStop.time, units: [2, 2]),
          exposure(dose, 5, stop: PerformanceExecutionStop.time, units: [2, 2]),
        ],
      ];
      for (final history in histories) {
        final result = evaluate(dose, history: history);
        expect(result.action, PerformanceProgressionAction.maintain);
        expect(result.dose, dose);
      }
    },
  );

  test('dificultad repetida o incumplimiento objetivo reducen una serie', () {
    final dose = reps();
    for (final history in [
      [exposure(dose, 2, rir: 1), exposure(dose, 5, rir: 1)],
      [
        exposure(dose, 2, technique: false),
        exposure(dose, 5, technique: false),
      ],
      [
        exposure(dose, 2, units: [7, 7]),
        exposure(dose, 5, units: [7, 7]),
      ],
    ]) {
      final result = evaluate(dose, history: history);
      expect(result.action, PerformanceProgressionAction.reduce);
      expect(result.dose!.targets, [8, 7]);
      expect(result.dose!.restSeconds, 120);
    }
  });

  test('respuesta mixta mantiene y dosis mínima difícil pide calibración', () {
    final dose = reps();
    expect(
      evaluate(
        dose,
        history: [exposure(dose, 2), exposure(dose, 5, rir: 1)],
      ).action,
      PerformanceProgressionAction.maintain,
    );
    for (final minimum in [
      reps(targets: [1]),
      duration(targets: [1]),
      load(targets: [4]),
    ]) {
      final result = evaluate(
        minimum,
        history: [
          exposure(minimum, 2, tolerated: false),
          exposure(minimum, 5, tolerated: false),
        ],
      );
      expect(
        result.proposal.status,
        PerformanceProposalStatus.needsCalibration,
      );
      expect(result.dose, isNull);
    }
  });

  test(
    'no reutiliza éxitos antiguos si las últimas dosis no son comparables',
    () {
      final dose = reps();
      final another = reps(targets: [9, 9]);
      expect(
        evaluate(
          dose,
          history: [exposure(another, 1), exposure(dose, 2), exposure(dose, 5)],
        ).action,
        PerformanceProgressionAction.maintain,
      );
      expect(
        evaluate(
          dose,
          history: [exposure(reps(protocol: 2), 2), exposure(dose, 5)],
        ).action,
        PerformanceProgressionAction.maintain,
      );
    },
  );

  test(
    'identidades duplicadas se rechazan y un día solo no son dos exposiciones',
    () {
      final dose = reps();
      expect(
        () => evaluate(
          dose,
          history: [
            exposure(dose, 2),
            exposure(dose, 5, id: 'exposure_2'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        evaluate(
          dose,
          history: [
            exposure(dose, 2, id: 'a'),
            exposure(dose, 2, id: 'b'),
          ],
        ).action,
        PerformanceProgressionAction.maintain,
      );
    },
  );

  test(
    'rechaza fechas futuras y exige referencia actual tras catorce días',
    () {
      final dose = reps();
      expect(
        evaluate(dose, history: [exposure(dose, -1)]).proposal.status,
        PerformanceProposalStatus.needsData,
      );
      expect(
        evaluate(
          dose,
          calibratedOn: now.add(const Duration(seconds: 1)),
        ).proposal.status,
        PerformanceProposalStatus.needsCalibration,
      );
      expect(
        evaluate(
          dose,
          calibratedOn: now.subtract(const Duration(days: 14, seconds: 1)),
        ).proposal.status,
        PerformanceProposalStatus.needsCalibration,
      );
      expect(
        evaluate(
          dose,
          calibratedOn: now.subtract(const Duration(days: 14)),
        ).dose,
        dose,
      );
    },
  );

  test('bloqueo, confirmación y material producen pendientes explícitos', () {
    final dose = reps(code: 'pull_up_pronated');
    expect(
      evaluate(dose, symptoms: true, confirmed: false).proposal.status,
      PerformanceProposalStatus.blocked,
    );
    expect(
      evaluate(dose, confirmed: false).proposal.status,
      PerformanceProposalStatus.needsData,
    );
    expect(
      evaluate(dose, equipment: {}).proposal.status,
      PerformanceProposalStatus.needsData,
    );
    expect(
      evaluate(reps(), equipment: {}).proposal.status,
      PerformanceProposalStatus.readyForReview,
    );
  });

  test('no declara cobertura de potencia, cronómetro ni versión distinta', () {
    final dose = reps();
    final timed = PerformanceTrainingGoal(
      id: 'timed',
      capability: PerformanceCapability.repetitionsInTime,
      questionBlock: PerformanceQuestionBlock.pushes,
      task: task('push_up_standard', StrengthMeasurement.repsInTime),
      loadMode: StrengthLoadMode.bodyweight,
    );
    expect(
      evaluate(dose, target: timed).proposal.status,
      PerformanceProposalStatus.unsupported,
    );
    expect(
      evaluate(
        dose,
        target: goal(dose, capability: PerformanceCapability.powerPractice),
      ).proposal.status,
      PerformanceProposalStatus.unsupported,
    );
    expect(
      evaluate(reps(version: 'old_policy')).proposal.status,
      PerformanceProposalStatus.unsupported,
    );
  });

  test(
    '52 decisiones consecutivas conservan descansos y cambios de una unidad',
    () {
      var dose = reps();
      for (var week = 0; week < 52; week++) {
        final result = evaluate(
          dose,
          history: [exposure(dose, 2), exposure(dose, 5)],
        );
        expect(
          result.dose!.targets.reduce((a, b) => a + b) -
              dose.targets.reduce((a, b) => a + b),
          1,
        );
        expect(result.dose!.restSeconds, 120);
        expect(result.dose!.targets.length, 2);
        dose = result.dose!;
      }
      // Invariante informática; no simula calendario ni predice mejora humana.
      expect(dose.targets, [34, 34]);
    },
  );

  test(
    'una referencia de banca con otro montaje no cubre el objetivo de RM',
    () {
      final dose = load();
      final target = PerformanceTrainingGoal(
        id: 'different_setup',
        capability: PerformanceCapability.maximalStrength,
        questionBlock: PerformanceQuestionBlock.strengthAndLowerBody,
        loadMode: StrengthLoadMode.externalLoad,
        task: StrengthTask(
          exerciseCode: 'bench_press_barbell',
          exerciseVersion: 1,
          protocolKey: 'bench_exam',
          protocolVersion: 1,
          setupKey: 'different_grip',
          measurement: StrengthMeasurement.maxLoad,
        ),
      );
      expect(
        evaluate(dose, target: target).proposal.status,
        PerformanceProposalStatus.unsupported,
      );
      expect(
        evaluate(dose).proposal.status,
        PerformanceProposalStatus.readyForReview,
      );
    },
  );

  test('el lastre conserva masa corporal sin inventar cobertura de RM', () {
    PerformanceProgressionDose weighted(double? mass) =>
        PerformanceProgressionDose(
          task: task('pull_up_weighted', StrengthMeasurement.loadReps),
          model: PerformanceProgressionModel.loadAndRepetitions,
          loadMode: StrengthLoadMode.bodyweightPlusExternal,
          targets: [4, 4],
          restSeconds: 120,
          targetRir: 3,
          loadKg: 10,
          bodyMassKg: mass,
        );
    expect(() => weighted(null), throwsArgumentError);
    final dose = weighted(70);
    final changed = dose.withTargets([5, 4]);
    expect(changed.targets, [5, 4]);
    expect(changed.loadKg, 10);
    expect(changed.bodyMassKg, 70);
    expect(dose, isNot(weighted(72)));
    // El perfil real admite LOAD_REPS, aún no MAX_LOAD. No inventar un RM.
    expect(
      evaluate(dose).proposal.status,
      PerformanceProposalStatus.unsupported,
    );
  });

  test(
    'un ejercicio pliométrico no usa progresión de máximas repeticiones',
    () {
      expect(
        catalog
            .firstWhere((p) => p.code == 'pogo_jumps')
            .supports(StrengthMeasurement.reps, StrengthLoadMode.bodyweight),
        isTrue,
      );
      expect(
        evaluate(reps(code: 'pogo_jumps')).proposal.status,
        PerformanceProposalStatus.unsupported,
      );
    },
  );

  test('datos numéricos inválidos e isometría con RIR se rechazan', () {
    expect(() => reps(targets: [0]), throwsArgumentError);
    expect(
      () => PerformanceProgressionSet(rir: double.nan),
      throwsArgumentError,
    );
    expect(
      () => PerformanceProgressionRules(loadStepKg: double.infinity),
      throwsArgumentError,
    );
    expect(
      () => PerformanceProgressionDose(
        task: duration().task,
        model: PerformanceProgressionModel.duration,
        loadMode: StrengthLoadMode.bodyweight,
        targets: [20],
        restSeconds: 60,
        targetRir: 3,
      ),
      throwsArgumentError,
    );
    final targets = [8, 8];
    final dose = reps(targets: targets);
    targets[0] = 100;
    expect(dose.targets, [8, 8]);
    expect(() => dose.targets.add(1), throwsUnsupportedError);
  });
}
