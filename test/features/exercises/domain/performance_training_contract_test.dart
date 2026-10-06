import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_training_contract.dart';
import 'package:workout_core/push_up_performance_proposal.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:workout_core/strength_training_policy.dart';

import 'strength_exercise_catalog_test.dart' show readCatalogJson;

void main() {
  final catalog = StrengthExerciseCatalogCodec.decode(readCatalogJson());
  final now = DateTime.utc(2026, 10, 3);
  StrengthTask task({
    String code = 'push_up_standard',
    int version = 1,
    StrengthMeasurement measurement = StrengthMeasurement.reps,
  }) => StrengthTask(
    exerciseCode: code,
    exerciseVersion: 1,
    protocolKey: '${code}_practice',
    protocolVersion: version,
    setupKey: 'reviewed_setup',
    measurement: measurement,
  );
  PerformanceTrainingGoal goal({
    String id = 'push_goal',
    StrengthTask? target,
    PerformanceCapability capability = PerformanceCapability.repetitions,
    PerformanceQuestionBlock block = PerformanceQuestionBlock.pushes,
    StrengthLoadMode loadMode = StrengthLoadMode.bodyweight,
  }) => PerformanceTrainingGoal(
    id: id,
    task: target ?? task(),
    capability: capability,
    questionBlock: block,
    loadMode: loadMode,
  );
  StrengthWorkPrescription dose() => StrengthWorkPrescription(
    policyVersion: PushUpRepetitionsPolicy.version,
    goal: task(),
    task: task(),
    setCount: 2,
    repsPerSet: 8,
    targetRir: 3,
    restSeconds: 120,
  );
  StrengthTrainingDecision decision({
    bool confirmed = true,
    double rir = 3,
    StrengthTask? target,
    bool symptoms = false,
    int seconds = 1200,
  }) => PushUpRepetitionsPolicy().preview(
    goal: target ?? task(),
    catalog: catalog.exercises,
    equipment: const {},
    references: [
      StrengthWorkingReference(
        task: task(),
        validReps: 8,
        reportedRir: rir,
        observedOn: now.subtract(const Duration(days: 1)),
        currentCapacityConfirmed: confirmed,
      ),
    ],
    slots: [
      StrengthDaySlot(day: 0, availableSeconds: seconds),
      StrengthDaySlot(day: 3, availableSeconds: seconds),
    ],
    now: now,
    currentContextConfirmed: confirmed,
    hasSymptoms: symptoms,
  );
  PerformanceModuleProposal ready(
    PerformanceTrainingGoal target,
    List<PerformanceProposedWork> work,
  ) => PerformanceModuleProposal(
    goal: target,
    status: PerformanceProposalStatus.readyForReview,
    policyStage: PerformancePolicyStage.experimental,
    policyVersion: PushUpRepetitionsPolicy.version,
    reasons: const ['specificPractice'],
    work: work,
  );

  test('representa todas las mediciones/cargas de las 63 variantes sin acreditar políticas', () {
    var combinations = 0;
    for (final definition in catalog.exercises) {
      for (final option in definition.measurements) {
        final capability = switch (option.mode) {
          StrengthMeasurement.reps ||
          StrengthMeasurement.loadReps => PerformanceCapability.repetitions,
          StrengthMeasurement.repsInTime =>
            PerformanceCapability.repetitionsInTime,
          StrengthMeasurement.maxLoad => PerformanceCapability.maximalStrength,
          StrengthMeasurement.duration =>
            definition.movementPatterns.contains('carry')
                ? PerformanceCapability.carry
                : PerformanceCapability.isometricEndurance,
          StrengthMeasurement.timeForDistance =>
            PerformanceCapability.ropeClimb,
          StrengthMeasurement.timeForCourse =>
            definition.movementPatterns.contains('reactive_agility')
                ? PerformanceCapability.reactiveAgility
                : PerformanceCapability.plannedCourse,
          StrengthMeasurement.distance =>
            definition.movementPatterns.contains('carry')
                ? PerformanceCapability.carry
                : PerformanceCapability.jumpOrThrow,
          StrengthMeasurement.height => PerformanceCapability.jumpOrThrow,
          StrengthMeasurement.passFail =>
            definition.movementPatterns.contains('reactive_agility')
                ? PerformanceCapability.reactiveAgility
                : PerformanceCapability.ropeClimb,
          StrengthMeasurement.reactiveMetrics =>
            PerformanceCapability.powerPractice,
        };
        for (final load in option.loadModes) {
          final objective = goal(
            id: '${definition.code}/${option.mode.code}/${load.code}',
            target: task(code: definition.code, measurement: option.mode),
            capability: capability,
            loadMode: load,
          );
          expect(objective.isRepresentedBy(definition), isTrue);
          final preview = PerformancePreparationPreview(
            goals: [objective],
            proposals: const [],
          );
          expect(
            preview.pending.single.status,
            PerformanceProposalStatus.unsupported,
          );
          expect(preview.work, isEmpty);
          combinations++;
        }
      }
    }
    expect(catalog.exercises.length, 63);
    expect(combinations, greaterThanOrEqualTo(63));
  });

  test(
    'capacidad y carga incompatibles no se aceptan por compartir ejercicio',
    () {
      expect(
        () => goal(capability: PerformanceCapability.plannedCourse),
        throwsArgumentError,
      );
      expect(
        () => goal(
          target: task(measurement: StrengthMeasurement.maxLoad),
          capability: PerformanceCapability.maximalStrength,
        ),
        throwsArgumentError,
      );
      final target = goal(
        target: task(measurement: StrengthMeasurement.repsInTime),
        capability: PerformanceCapability.repetitionsInTime,
      );
      expect(
        target.isRepresentedBy(
          catalog.exercises.firstWhere((e) => e.code == 'push_up_incline'),
        ),
        isFalse,
      );
    },
  );

  test('compartir unidad no convierte transporte en isometría ni reacción en circuito fijo', () {
    final carry = catalog.exercises.firstWhere((e) => e.code == 'farmer_carry');
    final isometric = goal(
      target: task(code: carry.code, measurement: StrengthMeasurement.duration),
      capability: PerformanceCapability.isometricEndurance,
      loadMode: StrengthLoadMode.externalLoad,
    );
    expect(isometric.isRepresentedBy(carry), isFalse);
    final reactive = catalog.exercises.firstWhere(
      (e) => e.code == 'reactive_direction_drill',
    );
    final planned = goal(
      target: task(
        code: reactive.code,
        measurement: StrengthMeasurement.timeForCourse,
      ),
      capability: PerformanceCapability.plannedCourse,
    );
    expect(planned.isRepresentedBy(reactive), isFalse);
  });

  test('no mezcla necesidades de referencia de dos protocolos aunque tengan la misma clave', () {
    final first = goal();
    final second = goal(id: 'another_protocol', target: task(version: 2));
    PerformanceModuleProposal pending(PerformanceTrainingGoal target) =>
        PerformanceModuleProposal(
          goal: target,
          status: PerformanceProposalStatus.needsCalibration,
          policyStage: PerformancePolicyStage.experimental,
          policyVersion: 'test_v1',
          reasons: const ['calibrationMissing'],
          requirements: [
            PerformanceDataRequirement(
              key: 'working_reference',
              reason: 'calibrationMissing',
              task: target.task,
            ),
          ],
        );
    final preview = PerformancePreparationPreview(
      goals: [first, second],
      proposals: [pending(first), pending(second)],
    );
    expect(preview.requirements.length, 2);
  });

  test(
    'genera solo bloques pertinentes, sin repetir el bloque por objetivo',
    () {
      final goals = [
        goal(),
        goal(
          id: 'timed_push',
          target: task(measurement: StrengthMeasurement.repsInTime),
          capability: PerformanceCapability.repetitionsInTime,
        ),
        goal(
          id: 'plank',
          target: task(
            code: 'front_plank_forearms',
            measurement: StrengthMeasurement.duration,
          ),
          capability: PerformanceCapability.isometricEndurance,
          block: PerformanceQuestionBlock.isometrics,
        ),
      ];
      final preview = PerformancePreparationPreview(
        goals: goals,
        proposals: const [],
      );
      expect(preview.questionBlocks, [
        PerformanceQuestionBlock.pushes,
        PerformanceQuestionBlock.isometrics,
      ]);
      expect(
        preview.questionBlocks,
        isNot(contains(PerformanceQuestionBlock.rope)),
      );
      expect(preview.pending.length, 3);
    },
  );

  test('carrera puede representarse en la frontera sin ejecutar o modificar su motor', () {
    final running = goal(
      id: 'running',
      target: task(
        code: 'running',
        measurement: StrengthMeasurement.timeForDistance,
      ),
      capability: PerformanceCapability.running,
      block: PerformanceQuestionBlock.running,
    );
    final preview = PerformancePreparationPreview(
      goals: [running],
      proposals: const [],
    );
    expect(preview.questionBlocks, [PerformanceQuestionBlock.running]);
    expect(
      preview.pending.single.policyStage,
      PerformancePolicyStage.unavailable,
    );
    expect(preview.pending.single.policyVersion, isNull);
  });

  test(
    'flexiones conserva dosis y separación, y sigue siendo experimental',
    () {
      final target = goal();
      final result = decision();
      final proposal = pushUpPerformanceProposal(
        goal: target,
        decision: result,
      );
      final preview = PerformancePreparationPreview(
        goals: [target],
        proposals: [proposal],
      );
      expect(preview.allGoalsReadyForReview, isTrue);
      expect(preview.hasExperimentalPolicies, isTrue);
      expect(preview.work.map((w) => w.preferredDay), [0, 3]);
      for (var i = 0; i < preview.work.length; i++) {
        final converted =
            preview.work[i].prescription as PushUpPerformancePrescription;
        expect(converted.dose, result.sessions[i].prescription);
        expect(
          converted.estimatedSeconds,
          result.sessions[i].prescription.estimatedSeconds,
        );
      }
    },
  );

  test('una propuesta lista no oculta el objetivo de cuerda sin política', () {
    final push = goal();
    final rope = goal(
      id: 'rope',
      target: task(
        code: 'rope_climb',
        measurement: StrengthMeasurement.passFail,
      ),
      capability: PerformanceCapability.ropeClimb,
      block: PerformanceQuestionBlock.rope,
    );
    final preview = PerformancePreparationPreview(
      goals: [push, rope],
      proposals: [pushUpPerformanceProposal(goal: push, decision: decision())],
    );
    expect(preview.allGoalsReadyForReview, isFalse);
    expect(preview.proposals.length, 2);
    expect(preview.pending.single.goal, rope);
    expect(preview.work.length, 2);
  });

  test('distingue contexto, calibración, molestias y conflicto de agenda', () {
    final cases = [
      (
        decision(confirmed: false),
        PerformanceProposalStatus.needsData,
        'current_context',
      ),
      (
        decision(rir: 9),
        PerformanceProposalStatus.needsCalibration,
        'comparable_working_reference',
      ),
      (decision(symptoms: true), PerformanceProposalStatus.blocked, null),
      (decision(seconds: 60), PerformanceProposalStatus.agendaConflict, null),
    ];
    for (final (result, expected, requirement) in cases) {
      final proposal = pushUpPerformanceProposal(
        goal: goal(),
        decision: result,
      );
      expect(proposal.status, expected);
      expect(proposal.work, isEmpty);
      if (requirement != null) {
        expect(proposal.requirements.single.key, requirement);
      }
    }
  });

  test(
    'no ofrece una dosis de flexiones normales para el objetivo cronometrado',
    () {
      final target = goal(
        target: task(measurement: StrengthMeasurement.repsInTime),
        capability: PerformanceCapability.repetitionsInTime,
      );
      final proposal = pushUpPerformanceProposal(
        goal: target,
        decision: decision(target: target.task),
      );
      expect(proposal.status, PerformanceProposalStatus.unsupported);
      expect(proposal.work, isEmpty);
      final incompatibleDose = StrengthWorkPrescription(
        policyVersion: PushUpRepetitionsPolicy.version,
        goal: target.task,
        task: task(),
        setCount: 2,
        repsPerSet: 8,
        targetRir: 3,
        restSeconds: 120,
      );
      expect(
        () => pushUpPerformanceProposal(
          goal: target,
          decision: StrengthTrainingDecision(
            status: StrengthDecisionStatus.ready,
            action: StrengthDoseAction.initial,
            reasons: const [StrengthDecisionReason.initialDose],
            sessions: [
              StrengthScheduledWork(day: 0, prescription: incompatibleDose),
            ],
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'rechaza objetivos duplicados, propuestas ajenas y protocolo cambiado',
    () {
      final target = goal();
      final proposal = pushUpPerformanceProposal(
        goal: target,
        decision: decision(),
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [target, target],
          proposals: [],
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [target],
          proposals: [proposal, proposal],
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [goal(id: 'other')],
          proposals: [proposal],
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [goal(target: task(version: 2))],
          proposals: [proposal],
        ),
        throwsArgumentError,
      );
      expect(
        () => pushUpPerformanceProposal(
          goal: goal(target: task(version: 2)),
          decision: decision(),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'un trabajo compartido se cuenta una vez y contradicciones se rechazan',
    () {
      final first = goal();
      final second = goal(id: 'second_goal');
      final shared = PerformanceProposedWork(
        id: 'shared_work',
        goalIds: [first.id, second.id],
        prescription: PushUpPerformancePrescription(dose()),
        preferredDay: 0,
      );
      final preview = PerformancePreparationPreview(
        goals: [first, second],
        proposals: [
          ready(first, [shared]),
          ready(second, [shared]),
        ],
      );
      expect(preview.work, [shared]);
      final other = PerformanceProposedWork(
        id: shared.id,
        goalIds: shared.goalIds,
        prescription: shared.prescription,
        preferredDay: 3,
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [first, second],
          proposals: [
            ready(first, [shared]),
            ready(second, [other]),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformancePreparationPreview(
          goals: [first],
          proposals: [
            ready(first, [shared]),
          ],
        ),
        throwsArgumentError,
      );
    },
  );

  test('las colecciones son inmutables y los datos comunes no se repiten', () {
    final first = goal();
    final second = goal(id: 'second');
    final requirement = PerformanceDataRequirement(
      key: 'current_context',
      reason: 'contextMissing',
    );
    PerformanceModuleProposal pending(PerformanceTrainingGoal target) =>
        PerformanceModuleProposal(
          goal: target,
          status: PerformanceProposalStatus.needsData,
          policyStage: PerformancePolicyStage.experimental,
          policyVersion: 'test_v1',
          reasons: const ['contextMissing'],
          requirements: [requirement],
        );
    final source = [first, second];
    final preview = PerformancePreparationPreview(
      goals: source,
      proposals: [pending(first), pending(second)],
    );
    source.clear();
    expect(preview.goals.length, 2);
    expect(preview.requirements, [requirement]);
    expect(() => preview.goals.clear(), throwsUnsupportedError);
    expect(() => preview.proposals.clear(), throwsUnsupportedError);
    expect(() => preview.requirements.clear(), throwsUnsupportedError);
  });

  test(
    'no acepta una propuesta lista vacía ni trabajo en un estado pendiente',
    () {
      expect(() => ready(goal(), []), throwsArgumentError);
      expect(
        () => PerformanceModuleProposal(
          goal: goal(),
          status: PerformanceProposalStatus.needsCalibration,
          policyStage: PerformancePolicyStage.experimental,
          policyVersion: 'test_v1',
          reasons: const ['calibrationMissing'],
        ),
        throwsArgumentError,
      );
      expect(
        () => PerformanceModuleProposal(
          goal: goal(),
          status: PerformanceProposalStatus.blocked,
          policyStage: PerformancePolicyStage.experimental,
          policyVersion: 'test_v1',
          reasons: const ['symptoms'],
          work: [
            PerformanceProposedWork(
              id: 'work',
              goalIds: [goal().id],
              prescription: PushUpPerformancePrescription(dose()),
              preferredDay: 0,
            ),
          ],
        ),
        throwsArgumentError,
      );
    },
  );
}
