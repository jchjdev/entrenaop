import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:workout_core/strength_training_policy.dart';

import 'strength_exercise_catalog_test.dart' show readCatalogJson;

void main() {
  final now = DateTime.utc(2026, 10, 3);
  final catalog = StrengthExerciseCatalogCodec.decode(readCatalogJson());
  final policy = PushUpRepetitionsPolicy();
  StrengthTask task({
    String code = 'push_up_standard',
    String setup = 'floor',
    int protocolVersion = 1,
    StrengthMeasurement measurement = StrengthMeasurement.reps,
  }) => StrengthTask(
    exerciseCode: code,
    exerciseVersion: 1,
    protocolKey: '${code}_practice',
    protocolVersion: protocolVersion,
    setupKey: setup,
    measurement: measurement,
  );
  final goal = task();
  StrengthWorkingReference reference({
    StrengthTask? variant,
    int reps = 8,
    double rir = 3,
    bool confirmed = true,
    DateTime? date,
  }) => StrengthWorkingReference(
    task: variant ?? goal,
    validReps: reps,
    reportedRir: rir,
    observedOn: date ?? now.subtract(const Duration(days: 10)),
    currentCapacityConfirmed: confirmed,
  );
  StrengthWorkPrescription dose({
    StrengthTask? variant,
    String version = PushUpRepetitionsPolicy.version,
    int reps = 8,
  }) => StrengthWorkPrescription(
    policyVersion: version,
    goal: goal,
    task: variant ?? goal,
    setCount: 2,
    repsPerSet: reps,
    targetRir: 3,
    restSeconds: 120,
  );
  StrengthExposure exposure(
    String id, {
    StrengthWorkPrescription? prescription,
    int reps = 8,
    double? rir = 3,
    bool valid = true,
    StrengthInterruption interruption = StrengthInterruption.none,
    int daysAgo = 2,
    int sets = 2,
  }) => StrengthExposure(
    id: id,
    performedOn: now.subtract(Duration(days: daysAgo)),
    prescription: prescription ?? dose(),
    interruption: interruption,
    sets: [
      for (var i = 0; i < sets; i++)
        StrengthSetObservation(
          validReps: reps,
          techniqueValid: valid,
          reportedRir: rir,
        ),
    ],
  );
  StrengthTrainingDecision preview({
    StrengthTask? objective,
    List<StrengthWorkingReference>? references,
    Set<String> equipment = const {},
    List<StrengthDaySlot>? slots,
    bool confirmed = true,
    bool symptoms = false,
    StrengthWorkPrescription? previous,
    List<StrengthExposure> history = const [],
  }) => policy.preview(
    goal: objective ?? goal,
    catalog: catalog.exercises,
    equipment: equipment,
    references: references ?? [reference()],
    slots:
        slots ??
        [
          StrengthDaySlot(day: 0, availableSeconds: 1200),
          StrengthDaySlot(day: 3, availableSeconds: 1200),
        ],
    now: now,
    currentContextConfirmed: confirmed,
    hasSymptoms: symptoms,
    previousPrescription: previous,
    history: history,
  );

  test('mismo objetivo: dosis distinta por capacidad, no por azar', () {
    final first = preview();
    final second = preview(references: [reference(reps: 16)]);
    expect(first.sessions.first.prescription.repsPerSet, 8);
    expect(second.sessions.first.prescription.repsPerSet, 16);
    expect(
      preview().sessions.first.prescription,
      first.sessions.first.prescription,
    );
    expect(
      first.sessions.first.prescription.goal,
      second.sessions.first.prescription.goal,
    );
  });
  test('la práctica específica gana a un apoyo con más repeticiones', () {
    final result = preview(
      equipment: {'stable_support'},
      references: [
        reference(
          variant: task(code: 'push_up_incline', setup: 'height_80_cm'),
          reps: 20,
        ),
        reference(),
      ],
    );
    expect(result.sessions.first.prescription.task, goal);
    expect(result.reasons, contains(StrengthDecisionReason.specificPractice));
  });
  test('inclinada accesible necesita material y conserva montaje separado', () {
    final support = task(code: 'push_up_incline', setup: 'height_80_cm');
    final references = [reference(variant: support)];
    expect(
      preview(references: references).status,
      StrengthDecisionStatus.needsCalibration,
    );
    final result = preview(
      references: references,
      equipment: {'stable_support'},
    );
    expect(result.status, StrengthDecisionStatus.ready);
    expect(result.sessions.first.prescription.task, support);
    expect(result.sessions.first.prescription.goal, goal);
    expect(result.reasons, contains(StrengthDecisionReason.accessibleSupport));
  });
  test('no selecciona dominadas o banca por grupos musculares', () {
    for (final code in ['pull_up_pronated', 'bench_press_barbell']) {
      expect(
        preview(
          references: [reference(variant: task(code: code))],
          equipment: {'barbell', 'bench', 'pull_up_bar'},
        ).status,
        StrengthDecisionStatus.needsCalibration,
      );
    }
  });
  test(
    'protocolo incompatible no se convierte en una referencia equivalente',
    () {
      expect(
        preview(references: [reference(variant: task(protocolVersion: 2))])
            .status,
        StrengthDecisionStatus.needsCalibration,
      );
      expect(
        preview(objective: task(measurement: StrengthMeasurement.repsInTime))
            .status,
        StrengthDecisionStatus.unsupported,
      );
    },
  );
  test('molestias y contexto sin confirmar no producen sesiones', () {
    expect(preview(symptoms: true).status, StrengthDecisionStatus.blocked);
    expect(preview(symptoms: true).sessions, isEmpty);
    expect(
      preview(confirmed: false).status,
      StrengthDecisionStatus.needsContext,
    );
    expect(
      preview(references: [reference(confirmed: false)]).status,
      StrengthDecisionStatus.needsCalibration,
    );
  });
  test('no calibra a partir de esfuerzo extremo o referencia futura', () {
    for (final rir in [0.0, 1.0, 8.0, 10.0]) {
      expect(
        preview(references: [reference(rir: rir)]).status,
        StrengthDecisionStatus.needsCalibration,
      );
    }
    expect(
      preview(references: [reference(date: now.add(const Duration(days: 1)))])
          .status,
      StrengthDecisionStatus.needsCalibration,
    );
  });
  test(
    'la agenda reserva tiempo de otras pruebas y busca una pareja viable',
    () {
      final result = preview(
        slots: [
          StrengthDaySlot(day: 0, availableSeconds: 600, reservedSeconds: 300),
          StrengthDaySlot(
            day: 1,
            availableSeconds: 1200,
            pushWorkReserved: true,
          ),
          StrengthDaySlot(day: 2, availableSeconds: 1200),
          StrengthDaySlot(day: 5, availableSeconds: 1200),
        ],
      );
      expect(result.sessions.map((s) => s.day), [2, 5]);
      expect(
        preview(slots: [StrengthDaySlot(day: 0, availableSeconds: 300)]).status,
        StrengthDecisionStatus.noSpace,
      );
    },
  );
  test('domingo-lunes no se consideran separados al repetir la semana', () {
    final result = preview(
      slots: [
        StrengthDaySlot(day: 0, availableSeconds: 1200),
        StrengthDaySlot(day: 6, availableSeconds: 1200),
      ],
    );
    expect(result.sessions, hasLength(1));
    expect(result.reasons, contains(StrengthDecisionReason.agendaLimited));
  });
  test('dos respuestas toleradas progresan solo repeticiones', () {
    final previous = dose();
    final result = preview(
      previous: previous,
      history: [exposure('b', daysAgo: 2), exposure('a', daysAgo: 5)],
    );
    final next = result.sessions.first.prescription;
    expect(result.action, StrengthDoseAction.progress);
    expect(next.repsPerSet, 9);
    expect(next.setCount, previous.setCount);
    expect(next.restSeconds, previous.restSeconds);
    expect(next.targetRir, previous.targetRir);
  });
  test('una sesión, dato ausente o interrupción de agenda no progresan', () {
    for (final history in [
      [exposure('a')],
      [exposure('a', rir: null), exposure('b', rir: null, daysAgo: 5)],
      [
        exposure('a', interruption: StrengthInterruption.time),
        exposure('b', interruption: StrengthInterruption.time, daysAgo: 5),
      ],
      [exposure('a', sets: 1), exposure('b', sets: 1, daysAgo: 5)],
    ]) {
      final result = preview(previous: dose(), history: history);
      expect(result.action, StrengthDoseAction.hold);
      expect(result.sessions.first.prescription.repsPerSet, 8);
    }
  });
  test('una sesión difícil aislada no reduce pero dos sí', () {
    expect(
      preview(previous: dose(), history: [exposure('a', rir: 1)]).action,
      StrengthDoseAction.hold,
    );
    final result = preview(
      previous: dose(),
      history: [exposure('a', rir: 1), exposure('b', rir: 1, daysAgo: 5)],
    );
    expect(result.action, StrengthDoseAction.reduce);
    expect(result.sessions.first.prescription.repsPerSet, 7);
  });
  test(
    'pérdida de técnica no cuenta como progreso aunque suba el contador',
    () {
      final result = preview(
        previous: dose(),
        history: [
          exposure('a', reps: 20, valid: false),
          exposure('b', reps: 20, valid: false, daysAgo: 5),
        ],
      );
      expect(result.action, StrengthDoseAction.reduce);
    },
  );
  test(
    'al llegar a la dosis mínima pide recalibrar y no recorta hasta cero',
    () {
      final minimum = dose(reps: 1);
      final result = preview(
        previous: minimum,
        history: [
          exposure('a', prescription: minimum, reps: 1, rir: 1),
          exposure('b', prescription: minimum, reps: 1, rir: 1, daysAgo: 5),
        ],
      );
      expect(result.status, StrengthDecisionStatus.needsCalibration);
      expect(result.sessions, isEmpty);
    },
  );
  test('no mezcla versiones de política, protocolo o altura', () {
    expect(
      preview(previous: dose(version: 'old_policy')).status,
      StrengthDecisionStatus.needsCalibration,
    );
    final result = preview(
      previous: dose(),
      history: [
        exposure(
          'a',
          prescription: dose(variant: task(setup: 'different_rom')),
        ),
        exposure(
          'b',
          prescription: dose(variant: task(setup: 'different_rom')),
          daysAgo: 5,
        ),
      ],
    );
    expect(result.action, StrengthDoseAction.hold);
    expect(
      result.reasons,
      contains(StrengthDecisionReason.comparableHistoryMissing),
    );
  });
  test(
    'no duplica días o ejecuciones para fabricar frecuencia o tendencia',
    () {
      expect(
        () => preview(
          slots: [
            StrengthDaySlot(day: 0, availableSeconds: 1200),
            StrengthDaySlot(day: 0, availableSeconds: 1200),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            preview(previous: dose(), history: [exposure('a'), exposure('a')]),
        throwsArgumentError,
      );
    },
  );
  test('referencias contradictorias y dos registros del mismo día no fabrican progreso', () {
    expect(
      preview(references: [reference(reps: 8), reference(reps: 12)]).status,
      StrengthDecisionStatus.needsCalibration,
    );
    expect(
      preview(previous: dose(), history: [exposure('a'), exposure('b')]).action,
      StrengthDoseAction.hold,
    );
  });

  test(
    'observaciones y decisiones son inmutables y rechazan números no válidos',
    () {
      final result = preview();
      expect(() => result.sessions.clear(), throwsUnsupportedError);
      expect(() => reference(rir: double.nan), throwsArgumentError);
      expect(() => reference(reps: 0), throwsArgumentError);
      expect(
        () => StrengthSetObservation(validReps: -1, techniqueValid: true),
        throwsArgumentError,
      );
      expect(
        () => StrengthDaySlot(day: 7, availableSeconds: 100),
        throwsArgumentError,
      );
    },
  );
}
