import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

enum FasPeriodicScoringPolicy { literalRowsV2, bestThresholdV1 }

/// Calculador puro: no lee assets, no guarda intentos y no depende de Flutter.
class FasPeriodicScoreCalculator {
  const FasPeriodicScoreCalculator();

  FasPeriodicScoreCalculation calculate({
    required FasPeriodicScoreScale scale,
    required int mark,
    FasPeriodicScoringPolicy policy = FasPeriodicScoringPolicy.literalRowsV2,
  }) {
    if (mark < 0) throw ArgumentError.value(mark, 'mark');
    final scoredMark = mark - (mark % scale.markResolution);
    return FasPeriodicScoreCalculation(
      rawMark: mark,
      scoredMark: scoredMark,
      points: switch (policy) {
        FasPeriodicScoringPolicy.literalRowsV2 => _literalScore(
          scale,
          scoredMark,
        ),
        FasPeriodicScoringPolicy.bestThresholdV1 => _legacyScore(
          scale,
          scoredMark,
        ),
      },
    );
  }

  int? _literalScore(FasPeriodicScoreScale scale, int mark) {
    FasPeriodicScoreThreshold? easier;
    FasPeriodicScoreThreshold? harder;
    final higherIsBetter = scale.betterDirection == BetterDirection.higher;
    for (final row in scale.thresholds) {
      if (row.mark == mark) return row.points;
      if (higherIsBetter ? row.mark < mark : row.mark > mark) {
        if (easier == null ||
            (row.mark - mark).abs() < (easier.mark - mark).abs()) {
          easier = row;
        }
      } else if (harder == null ||
          (row.mark - mark).abs() < (harder.mark - mark).abs()) {
        harder = row;
      }
    }
    // Solo las dos filas que encierran la marca sirven para resolver el tramo.
    if (easier != null && harder != null && easier.points > harder.points) {
      return null;
    }
    return easier?.points ?? 0;
  }

  int _legacyScore(FasPeriodicScoreScale scale, int mark) {
    var points = 0;
    for (final threshold in scale.thresholds) {
      final reached = scale.betterDirection == BetterDirection.higher
          ? mark >= threshold.mark
          : mark <= threshold.mark;
      if (reached && threshold.points > points) points = threshold.points;
    }
    return points;
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
  final int? points;
}
