import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/initial_running_week_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = InitialRunningWeekPlanner();

  InitialRunningWeekInput input({
    int? days = 3,
    int? totalDays,
    int? strengthDays = 1,
    int? combinedDays = 0,
    int? recentDays = 3,
    int? reference = 600,
    bool pain = false,
    bool review = false,
    bool existing = false,
    String program = PreparationProgramIds.armedForcesTroopEntry,
  }) => InitialRunningWeekInput(
    programId: program,
    totalTrainingDaysPerWeek: totalDays ?? (days ?? 2) + 1,
    runningDaysPerWeek: days,
    allocatedStrengthDaysPerWeek: strengthDays,
    combinedDaysPerWeek: combinedDays,
    recentRunningDaysPerWeek: recentDays,
    reference2kSeconds: reference,
    sessionDurationMinutes: 45,
    requiresProfessionalReview: review,
    reportsPain: pain,
    alreadyHasOfficialRunningWeek: existing,
  );

  test('dos, tres y cuatro días conservan una sola calidad controlada', () {
    for (final days in [2, 3, 4]) {
      final decision = planner.plan(input(days: days));
      expect(decision.canPropose, isTrue);
      expect(decision.version, InitialRunningWeekPlanner.version);
      expect(decision.sessions.length, days);
      expect(
        decision.sessions.where(
          (item) => item == RunningWeekSessionKind.controlledQuality,
        ),
        hasLength(1),
      );
      expect(
        decision.reasons,
        contains(RunningWeekReason.noThresholdInferredFrom2k),
      );
    }
  });

  test('sin base reciente propone solo carrera fácil', () {
    final decision = planner.plan(input(days: 3, recentDays: 0));
    expect(decision.sessions, everyElement(RunningWeekSessionKind.easy));
    expect(decision.reasons, contains(RunningWeekReason.buildRunningBase));
  });

  test('dolor o revisión profesional bloquean la prescripción', () {
    for (final candidate in [input(pain: true), input(review: true)]) {
      final decision = planner.plan(candidate);
      expect(decision.canPropose, isFalse);
      expect(decision.blockers, contains(RunningWeekBlocker.healthReview));
      expect(decision.sessions, isEmpty);
    }
  });

  test('no infiere días de carrera de la disponibilidad general', () {
    final decision = planner.plan(input(days: null));
    expect(
      decision.blockers,
      contains(RunningWeekBlocker.missingRunningAvailability),
    );
  });

  test('dos días totales no se convierten en dos carreras más fuerza', () {
    final invalid = planner.plan(input(days: 2, totalDays: 2));
    expect(
      invalid.blockers,
      contains(RunningWeekBlocker.invalidProgramAllocation),
    );

    final valid = planner.plan(input(days: 1, totalDays: 2));
    expect(valid.sessions, [RunningWeekSessionKind.controlledQuality]);
  });

  test('una jornada mixta espera criterios de carga específicos', () {
    final decision = planner.plan(
      input(days: 2, totalDays: 2, combinedDays: 1),
    );
    expect(
      decision.blockers,
      contains(RunningWeekBlocker.combinedDayNeedsReview),
    );
  });

  test('no propone sin marca o si ya existe semana oficial', () {
    expect(planner.plan(input(reference: null)).canPropose, isFalse);
    expect(
      planner.plan(input(existing: true)).blockers,
      contains(RunningWeekBlocker.existingOfficialWeek),
    );
  });

  test('no aplica las reglas de Tropa a otro programa', () {
    final decision = planner.plan(input(program: 'other_program'));
    expect(decision.blockers, contains(RunningWeekBlocker.unsupportedProgram));
  });
}
