/// Ventana de reutilización de una medición de carrera para planificar.
/// No interpreta el resultado, comprueba el protocolo ni aprueba una pauta.
enum RunningReferenceReuseWindow { recent, conditional, expired, futureDate }

class RunningReferenceReuseAssessment {
  const RunningReferenceReuseAssessment({
    required this.window,
    required this.daysOld,
  });

  final RunningReferenceReuseWindow window;
  final int daysOld;
}

class RunningReferenceReusePolicy {
  const RunningReferenceReusePolicy();

  static const directSuggestionDays = 30;
  static const maximumReuseDays = 45;

  RunningReferenceReuseAssessment assess({
    required DateTime measuredAt,
    required DateTime now,
  }) {
    if (measuredAt.isAfter(now)) {
      return const RunningReferenceReuseAssessment(
        window: RunningReferenceReuseWindow.futureDate,
        daysOld: 0,
      );
    }

    // Fechas civiles en UTC: evita que un cambio horario altere el día 30/45.
    final measuredLocal = measuredAt.toLocal();
    final currentLocal = now.toLocal();
    final measuredDay = DateTime.utc(
      measuredLocal.year,
      measuredLocal.month,
      measuredLocal.day,
    );
    final currentDay = DateTime.utc(
      currentLocal.year,
      currentLocal.month,
      currentLocal.day,
    );
    final daysOld = currentDay.difference(measuredDay).inDays;

    if (daysOld <= directSuggestionDays) {
      return RunningReferenceReuseAssessment(
        window: RunningReferenceReuseWindow.recent,
        daysOld: daysOld,
      );
    }
    if (daysOld <= maximumReuseDays) {
      return RunningReferenceReuseAssessment(
        window: RunningReferenceReuseWindow.conditional,
        daysOld: daysOld,
      );
    }
    return RunningReferenceReuseAssessment(
      window: RunningReferenceReuseWindow.expired,
      daysOld: daysOld,
    );
  }
}
