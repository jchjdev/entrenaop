import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/fas_periodic_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = FasPeriodicScoreCalculator();

  test('elige el mejor umbral alcanzado sin depender del catálogo real', () {
    const scale = FasPeriodicScoreScale(
      testId: 'fixture_higher',
      betterDirection: BetterDirection.higher,
      thresholds: [
        FasPeriodicScoreThreshold(mark: 30, points: 100),
        FasPeriodicScoreThreshold(mark: 20, points: 40),
        FasPeriodicScoreThreshold(mark: 10, points: 20),
        FasPeriodicScoreThreshold(mark: 0, points: 0),
      ],
    );

    expect(calculator.calculate(scale: scale, mark: 9).points, 0);
    expect(calculator.calculate(scale: scale, mark: 10).points, 20);
    expect(calculator.calculate(scale: scale, mark: 25).points, 40);
    expect(calculator.calculate(scale: scale, mark: 99).points, 100);
  });

  test('en escalas descendentes no redondea a favor entre umbrales', () {
    const scale = FasPeriodicScoreScale(
      testId: 'fixture_lower',
      betterDirection: BetterDirection.lower,
      thresholds: [
        FasPeriodicScoreThreshold(mark: 10000, points: 100),
        FasPeriodicScoreThreshold(mark: 12000, points: 20),
        FasPeriodicScoreThreshold(mark: 13000, points: 0),
      ],
    );

    expect(calculator.calculate(scale: scale, mark: 12000).points, 20);
    expect(calculator.calculate(scale: scale, mark: 12001).points, 0);
  });

  test('trunca la marca a la resolución declarada', () {
    const scale = FasPeriodicScoreScale(
      testId: 'fixture_tenths',
      betterDirection: BetterDirection.lower,
      markResolution: 100,
      thresholds: [
        FasPeriodicScoreThreshold(mark: 15200, points: 20),
        FasPeriodicScoreThreshold(mark: 15300, points: 19),
      ],
    );

    final result = calculator.calculate(scale: scale, mark: 15299);
    expect(result.scoredMark, 15200);
    expect(result.points, 20);
  });
}
