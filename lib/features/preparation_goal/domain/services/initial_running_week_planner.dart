import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';

/// Primera decisión deportiva determinista del componente de carrera.
/// No crea sesiones ni estima umbrales; el plan conjunto debe reservar antes
/// los días de fuerza y asignar explícitamente los días de carrera.
class InitialRunningWeekPlanner {
  const InitialRunningWeekPlanner();

  static const version = 'tropa_running_initial_week_v1';

  InitialRunningWeekDecision plan(InitialRunningWeekInput input) {
    final blockers = <RunningWeekBlocker>[];
    if (input.programId != PreparationProgramIds.armedForcesTroopEntry) {
      blockers.add(RunningWeekBlocker.unsupportedProgram);
    }
    if (input.requiresProfessionalReview || input.reportsPain) {
      blockers.add(RunningWeekBlocker.healthReview);
    }
    if (!input.hasRunningDaysOrHistory) {
      blockers.add(RunningWeekBlocker.missingRunningAvailability);
    }
    if (input.allocatedStrengthDaysPerWeek == null ||
        input.combinedDaysPerWeek == null) {
      blockers.add(RunningWeekBlocker.missingStrengthAllocation);
    }
    if (input.runningDaysPerWeek != null &&
        (input.runningDaysPerWeek! < 1 || input.runningDaysPerWeek! > 4)) {
      blockers.add(RunningWeekBlocker.invalidRunningDays);
    }
    if (input.recentRunningDaysPerWeek != null &&
        (input.recentRunningDaysPerWeek! < 0 ||
            input.recentRunningDaysPerWeek! > 7)) {
      blockers.add(RunningWeekBlocker.invalidRunningHistory);
    }
    if (input.totalTrainingDaysPerWeek < 1 ||
        input.totalTrainingDaysPerWeek > 7 ||
        (input.allocatedStrengthDaysPerWeek != null &&
            input.allocatedStrengthDaysPerWeek! < 1) ||
        (input.combinedDaysPerWeek != null && input.combinedDaysPerWeek! < 0)) {
      blockers.add(RunningWeekBlocker.invalidProgramAllocation);
    }
    if (input.runningDaysPerWeek != null &&
        input.allocatedStrengthDaysPerWeek != null &&
        input.combinedDaysPerWeek != null &&
        (input.combinedDaysPerWeek! > input.runningDaysPerWeek! ||
            input.combinedDaysPerWeek! > input.allocatedStrengthDaysPerWeek! ||
            input.runningDaysPerWeek! +
                    input.allocatedStrengthDaysPerWeek! -
                    input.combinedDaysPerWeek! >
                input.totalTrainingDaysPerWeek)) {
      blockers.add(RunningWeekBlocker.invalidProgramAllocation);
    }
    if (input.combinedDaysPerWeek != null && input.combinedDaysPerWeek! > 0) {
      blockers.add(RunningWeekBlocker.combinedDayNeedsReview);
    }
    if (input.sessionDurationMinutes < 30) {
      blockers.add(RunningWeekBlocker.insufficientSessionTime);
    }
    if (input.reference2kSeconds == null ||
        input.reference2kSeconds! < 120 ||
        input.reference2kSeconds! > 7200) {
      blockers.add(RunningWeekBlocker.missingRunningReference);
    }
    if (input.alreadyHasOfficialRunningWeek) {
      blockers.add(RunningWeekBlocker.existingOfficialWeek);
    }
    if (blockers.isNotEmpty) {
      return InitialRunningWeekDecision(
        version: version,
        blockers: blockers,
        sessions: const [],
        reasons: const [],
      );
    }

    final days = input.runningDaysPerWeek!;
    final sessions = <RunningWeekSessionKind>[];
    // Sin base reciente, la primera semana familiariza con la carrera antes
    // de incorporar calidad. El test de 2 km no acredita tolerancia semanal.
    final canUseQuality = input.recentRunningDaysPerWeek! >= 2;
    if (canUseQuality) sessions.add(RunningWeekSessionKind.controlledQuality);
    if (sessions.isEmpty || days > 1) {
      sessions.add(RunningWeekSessionKind.easy);
    }
    while (sessions.length < days) {
      sessions.add(
        days == 4 && sessions.length == 3
            ? RunningWeekSessionKind.recovery
            : RunningWeekSessionKind.easy,
      );
    }

    return InitialRunningWeekDecision(
      version: version,
      blockers: const [],
      sessions: sessions,
      reasons: [
        if (canUseQuality)
          RunningWeekReason.oneControlledQuality
        else
          RunningWeekReason.buildRunningBase,
        if (sessions.contains(RunningWeekSessionKind.easy))
          RunningWeekReason.easyRunningIncluded,
        if (days == 1) RunningWeekReason.limitedRunningFrequency,
        RunningWeekReason.noThresholdInferredFrom2k,
      ],
    );
  }
}

class InitialRunningWeekInput {
  const InitialRunningWeekInput({
    required this.programId,
    required this.totalTrainingDaysPerWeek,
    required this.sessionDurationMinutes,
    required this.requiresProfessionalReview,
    required this.reportsPain,
    required this.alreadyHasOfficialRunningWeek,
    this.runningDaysPerWeek,
    this.allocatedStrengthDaysPerWeek,
    this.combinedDaysPerWeek,
    this.recentRunningDaysPerWeek,
    this.reference2kSeconds,
  });

  final String programId;
  final int totalTrainingDaysPerWeek;
  final int sessionDurationMinutes;
  final bool requiresProfessionalReview;
  final bool reportsPain;
  final bool alreadyHasOfficialRunningWeek;
  final int? runningDaysPerWeek;
  final int? allocatedStrengthDaysPerWeek;
  final int? combinedDaysPerWeek;
  final int? recentRunningDaysPerWeek;
  final int? reference2kSeconds;

  bool get hasRunningDaysOrHistory =>
      runningDaysPerWeek != null && recentRunningDaysPerWeek != null;
}

enum RunningWeekBlocker {
  unsupportedProgram,
  healthReview,
  missingRunningAvailability,
  missingStrengthAllocation,
  invalidRunningDays,
  invalidRunningHistory,
  invalidProgramAllocation,
  combinedDayNeedsReview,
  insufficientSessionTime,
  missingRunningReference,
  existingOfficialWeek,
}

enum RunningWeekSessionKind { controlledQuality, easy, recovery }

enum RunningWeekReason {
  oneControlledQuality,
  buildRunningBase,
  easyRunningIncluded,
  limitedRunningFrequency,
  noThresholdInferredFrom2k,
}

class InitialRunningWeekDecision {
  const InitialRunningWeekDecision({
    required this.version,
    required this.blockers,
    required this.sessions,
    required this.reasons,
  });

  final String version;
  final List<RunningWeekBlocker> blockers;
  final List<RunningWeekSessionKind> sessions;
  final List<RunningWeekReason> reasons;

  bool get canPropose => blockers.isEmpty;
}
