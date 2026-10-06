import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29);

  RunningInitialContext context({
    List<RecentRunningWeek>? history,
    RunningHealthCheck? health,
    InitialRunningReference? reference,
    int qualityWeeks = 0,
  }) => RunningInitialContext(
    goalId: 'fas-goal',
    programId: 'fas-periodic',
    collectedAt: now,
    availableMinutesByWeekday: const {1: 45, 3: 30, 6: 60},
    reservedStrengthWeekdays: const {3},
    recentRunningWeeks:
        history ??
        [
          RecentRunningWeek(
            weekStart: DateTime.utc(2026, 9, 21),
            runningDays: 0,
            runningMinutes: 0,
          ),
        ],
    health:
        health ??
        RunningHealthCheck(
          observedAt: now,
          reportsPain: false,
          requiresProfessionalReview: false,
        ),
    reference:
        reference ??
        InitialRunningReference.cooper(
          goalId: 'fas-goal',
          programId: 'fas-periodic',
          protocolVersion: 'cooper_12min_v1',
          measuredAt: DateTime.utc(2026, 9, 25),
          distanceMeters: 2300,
        ),
    qualityWeeksLastFour: qualityWeeks,
  );

  test('la calidad declarada exige semanas con carrera, no crea sesiones verificadas', () {
    expect(context(qualityWeeks: 1).inspect(now: now),
        contains(RunningContextIssue.invalidPriorQuality));
    expect(context(
      qualityWeeks: 1,
      history: [RecentRunningWeek(
        weekStart: DateTime.utc(2026, 9, 21),
        runningDays: 2,
        runningMinutes: 80,
      )],
    ).inspect(now: now), isEmpty);
  });

  test('cero carrera reciente es un dato válido y distinto de desconocido', () {
    expect(context().inspect(now: now), isEmpty);
    expect(
      context(history: const []).inspect(now: now),
      contains(RunningContextIssue.missingRecentLoad),
    );
  });

  test('un 2 km oficial del programa es una referencia candidata', () {
    final result = context(
      reference: InitialRunningReference.officialTwoKilometres(
        goalId: 'fas-goal',
        programId: 'fas-periodic',
        recordId: 'official-attempt-1',
        protocolVersion: 'run_2000m_v1',
        measuredAt: DateTime.utc(2026, 9, 25),
        durationSeconds: 650,
      ),
    ).inspect(now: now);
    expect(result, isEmpty);
  });

  test('un 2 km oficial ajeno no entra en la preparación', () {
    final result = context(
      reference: InitialRunningReference.officialTwoKilometres(
        goalId: 'other-goal',
        programId: 'other-program',
        recordId: 'official-attempt-2',
        protocolVersion: 'run_2000m_v1',
        measuredAt: DateTime.utc(2026, 9, 25),
        durationSeconds: 650,
      ),
    ).inspect(now: now);
    expect(
      result,
      contains(RunningContextIssue.referenceFromAnotherPreparation),
    );
  });

  test('una referencia de otro programa no se usa en FAS', () {
    final result = context(
      reference: InitialRunningReference.cooper(
        goalId: 'tropa-goal',
        programId: 'tropa',
        protocolVersion: 'cooper_12min_v1',
        measuredAt: now,
        distanceMeters: 2300,
      ),
    ).inspect(now: now);
    expect(
      result,
      contains(RunningContextIssue.referenceFromAnotherPreparation),
    );
  });

  test(
    'dolor declarado impide tratar la entrada como lista para planificar',
    () {
      final result = context(
        health: RunningHealthCheck(
          observedAt: now,
          reportsPain: true,
          requiresProfessionalReview: false,
        ),
      ).inspect(now: now);
      expect(result, contains(RunningContextIssue.healthReview));
    },
  );

  test('un test futuro o sin protocolo se señala como inválido', () {
    final result = context(
      reference: InitialRunningReference.vameval(
        goalId: 'fas-goal',
        programId: 'fas-periodic',
        protocolVersion: '',
        measuredAt: now.add(const Duration(days: 1)),
        speedKilometresPerHour: 15,
      ),
    ).inspect(now: now);
    expect(result, contains(RunningContextIssue.futureObservation));
    expect(result, contains(RunningContextIssue.invalidReference));
  });
}
