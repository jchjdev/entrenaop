/// Datos declarados para preparar carrera dentro de una preparación concreta.
/// Este contrato no decide la vigencia de los tests, convierte tests en ritmos
/// ni autoriza publicar sesiones.
class RunningInitialContext {
  const RunningInitialContext({
    required this.goalId,
    required this.programId,
    required this.collectedAt,
    required this.availableMinutesByWeekday,
    required this.reservedStrengthWeekdays,
    required this.recentRunningWeeks,
    required this.health,
    required this.reference,
    this.comfortableContinuousMinutes,
    this.targetTwoKilometreSeconds,
    this.officialMarginSeconds,
    this.qualityWeeksLastFour = 0,
  });

  static const version = 'running_initial_context_v3';

  final String goalId;
  final String programId;
  final DateTime collectedAt;

  /// Claves 1-7 según DateTime.monday...DateTime.sunday.
  final Map<int, int> availableMinutesByWeekday;
  final Set<int> reservedStrengthWeekdays;
  final List<RecentRunningWeek> recentRunningWeeks;
  final RunningHealthCheck? health;
  final InitialRunningReference? reference;

  /// Capacidad fácil declarada hoy. No representa carga semanal ni un test.
  /// Null identifica registros anteriores que aún no respondieron.
  final int? comfortableContinuousMinutes;

  /// Meta elegida; null significa mejorar sin una cifra obligatoria.
  final int? targetTwoKilometreSeconds;

  /// Margen elegido respecto al umbral del catálogo de esta preparación.
  /// Excluyente con una marca personal; null no impone margen alguno.
  final int? officialMarginSeconds;

  /// Semanas con al menos una calidad terminada, declaradas por el usuario.
  /// No equivalen a ejecuciones verificadas por EntrenaOP.
  final int qualityWeeksLastFour;

  List<RunningContextIssue> inspect({required DateTime now}) {
    final issues = <RunningContextIssue>[];
    if (qualityWeeksLastFour < 0 ||
        qualityWeeksLastFour > 4 ||
        qualityWeeksLastFour >
            recentRunningWeeks.where((week) => week.runningDays > 0).length) {
      issues.add(RunningContextIssue.invalidPriorQuality);
    }
    if (officialMarginSeconds != null &&
        (officialMarginSeconds! < 0 ||
            officialMarginSeconds! > 120 ||
            targetTwoKilometreSeconds != null)) {
      issues.add(RunningContextIssue.invalidTarget);
    }
    if (targetTwoKilometreSeconds != null &&
        (targetTwoKilometreSeconds! < 240 ||
            targetTwoKilometreSeconds! > 1800)) {
      issues.add(RunningContextIssue.invalidTarget);
    }
    if (goalId.trim().isEmpty || programId.trim().isEmpty) {
      issues.add(RunningContextIssue.missingPreparation);
    }
    if (collectedAt.isAfter(now)) {
      issues.add(RunningContextIssue.futureObservation);
    }
    if (comfortableContinuousMinutes case final minutes?) {
      if (minutes < 0 || minutes > 180) {
        issues.add(RunningContextIssue.invalidCurrentCapacity);
      }
    }
    if (availableMinutesByWeekday.isEmpty) {
      issues.add(RunningContextIssue.missingAvailability);
    } else if (availableMinutesByWeekday.entries.any(
      (entry) =>
          entry.key < DateTime.monday ||
          entry.key > DateTime.sunday ||
          entry.value <= 0,
    )) {
      issues.add(RunningContextIssue.invalidAvailability);
    }
    if (reservedStrengthWeekdays.any(
      (day) => !availableMinutesByWeekday.containsKey(day),
    )) {
      issues.add(RunningContextIssue.strengthOutsideAvailability);
    }
    if (recentRunningWeeks.isEmpty) {
      issues.add(RunningContextIssue.missingRecentLoad);
    } else if (recentRunningWeeks.any(
      (week) =>
          week.runningDays < 0 ||
          week.runningDays > 7 ||
          week.runningMinutes < 0 ||
          (week.runningDays == 0 && week.runningMinutes != 0) ||
          (week.runningDays > 0 && week.runningMinutes == 0) ||
          week.weekStart.isAfter(now),
    )) {
      issues.add(RunningContextIssue.invalidRecentLoad);
    }
    if (health == null) {
      issues.add(RunningContextIssue.missingHealthCheck);
    } else {
      if (health!.observedAt.isAfter(now)) {
        issues.add(RunningContextIssue.futureObservation);
      }
      if (health!.reportsPain || health!.requiresProfessionalReview) {
        issues.add(RunningContextIssue.healthReview);
      }
    }
    if (reference == null) {
      issues.add(RunningContextIssue.missingReference);
    } else {
      if (reference!.goalId != goalId || reference!.programId != programId) {
        issues.add(RunningContextIssue.referenceFromAnotherPreparation);
      }
      if (reference!.measuredAt.isAfter(now)) {
        issues.add(RunningContextIssue.futureObservation);
      }
      if (reference!.protocolVersion.trim().isEmpty ||
          (reference!.kind ==
                  InitialRunningReferenceKind.officialTwoKilometres &&
              (reference!.recordId == null ||
                  reference!.recordId!.trim().isEmpty)) ||
          !reference!.value.isFinite ||
          reference!.value <= 0) {
        issues.add(RunningContextIssue.invalidReference);
      }
    }
    return issues.toSet().toList(growable: false);
  }
}

class RecentRunningWeek {
  const RecentRunningWeek({
    required this.weekStart,
    required this.runningDays,
    required this.runningMinutes,
  });

  final DateTime weekStart;
  final int runningDays;
  final int runningMinutes;
}

class RunningHealthCheck {
  const RunningHealthCheck({
    required this.observedAt,
    required this.reportsPain,
    required this.requiresProfessionalReview,
  });

  final DateTime observedAt;
  final bool reportsPain;
  final bool requiresProfessionalReview;
}

enum InitialRunningReferenceKind {
  officialTwoKilometres,
  cooper12Minutes,
  vameval,
}

class InitialRunningReference {
  const InitialRunningReference.officialTwoKilometres({
    required this.goalId,
    required this.programId,
    required this.recordId,
    required this.protocolVersion,
    required this.measuredAt,
    required double durationSeconds,
  }) : kind = InitialRunningReferenceKind.officialTwoKilometres,
       value = durationSeconds;

  const InitialRunningReference.cooper({
    required this.goalId,
    required this.programId,
    required this.protocolVersion,
    required this.measuredAt,
    required double distanceMeters,
  }) : kind = InitialRunningReferenceKind.cooper12Minutes,
       value = distanceMeters,
       recordId = null;

  const InitialRunningReference.vameval({
    required this.goalId,
    required this.programId,
    required this.protocolVersion,
    required this.measuredAt,
    required double speedKilometresPerHour,
  }) : kind = InitialRunningReferenceKind.vameval,
       value = speedKilometresPerHour,
       recordId = null;

  final String goalId;
  final String programId;

  /// Identificador del intento oficial del que procede la marca, si aplica.
  final String? recordId;
  final InitialRunningReferenceKind kind;
  final String protocolVersion;
  final DateTime measuredAt;

  /// 2 km oficial: segundos. Cooper: metros en 12 min.
  /// VAMEVAL: velocidad final en km/h. Los puntos nunca son la referencia.
  /// La interpretación deportiva depende del protocolo y su versión.
  final double value;
}

enum RunningContextIssue {
  missingPreparation,
  futureObservation,
  missingAvailability,
  invalidAvailability,
  strengthOutsideAvailability,
  missingRecentLoad,
  invalidRecentLoad,
  missingHealthCheck,
  healthReview,
  missingReference,
  referenceFromAnotherPreparation,
  invalidReference,
  invalidCurrentCapacity,
  invalidTarget,
  invalidPriorQuality,
}
