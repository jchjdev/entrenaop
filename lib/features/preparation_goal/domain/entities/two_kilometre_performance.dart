/// Ancla de rendimiento de 2 km. La velocidad no es VAM ni un umbral medido.
class TwoKilometrePerformance {
  const TwoKilometrePerformance._(this.seconds);

  static const distanceMeters = 2000;

  final int seconds;

  static TwoKilometrePerformance? fromSeconds(int? seconds) {
    if (seconds == null || seconds < 120 || seconds > 7200) return null;
    return TwoKilometrePerformance._(seconds);
  }

  double get speedMetersPerSecond => distanceMeters / seconds;

  double get paceSecondsPerKilometre => seconds / 2;

  /// Brecha de velocidad para la misma distancia. No autoriza el ritmo objetivo.
  double speedGapTo(TwoKilometrePerformance target) =>
      target.speedMetersPerSecond / speedMetersPerSecond - 1;
}
