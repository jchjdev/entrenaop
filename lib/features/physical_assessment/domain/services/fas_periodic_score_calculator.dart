import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

/// Calculador puro: no lee assets, no guarda intentos y no depende de Flutter.
class FasPeriodicScoreCalculator {
  const FasPeriodicScoreCalculator();

  FasPeriodicScoreCalculation calculate({
    required FasPeriodicScoreScale scale,
    required int mark,
  }) {
    if (mark < 0) throw ArgumentError.value(mark, 'mark');
    final scoredMark = mark - (mark % scale.markResolution);
    var points = 0;
    for (final threshold in scale.thresholds) {
      final reached = scale.betterDirection == BetterDirection.higher
          ? scoredMark >= threshold.mark
          : scoredMark <= threshold.mark;
      if (reached && threshold.points > points) points = threshold.points;
    }
    return FasPeriodicScoreCalculation(
      rawMark: mark,
      scoredMark: scoredMark,
      points: points,
    );
  }
}

class FasPeriodicScoreScale {
  const FasPeriodicScoreScale({
    required this.testId,
    required this.betterDirection,
    required this.thresholds,
    this.markResolution = 1,
  }) : assert(markResolution > 0);

  final String testId;
  final BetterDirection betterDirection;
  final List<FasPeriodicScoreThreshold> thresholds;
  final int markResolution;
}

class FasPeriodicScoreThreshold {
  const FasPeriodicScoreThreshold({required this.mark, required this.points});
  final int mark;
  final int points;
}

class FasPeriodicScoreCalculation {
  const FasPeriodicScoreCalculation({
    required this.rawMark,
    required this.scoredMark,
    required this.points,
  });
  final int rawMark;
  final int scoredMark;
  final int points;
}
