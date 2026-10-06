import 'package:entrenaop/features/running_tools/domain/services/running_pace_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = RunningPaceCalculator();

  test('calcula un 400 a 3:40/km con pasos cada 100 metros', () {
    final result = calculator.calculate(
      paceSecondsPerKilometer: 220,
      distanceMeters: 400,
      splitMeters: 100,
    );

    expect(result.totalSeconds, 88);
    expect(result.splits.map((split) => split.cumulativeSeconds), [
      22,
      44,
      66,
      88,
    ]);
  });

  test('reparte el redondeo sin descuadrar parciales y tiempo final', () {
    final result = calculator.calculate(
      paceSecondsPerKilometer: 223,
      distanceMeters: 400,
      splitMeters: 100,
    );

    expect(result.totalSeconds, 89);
    expect(result.splits.map((split) => split.segmentSeconds), [
      22,
      23,
      22,
      22,
    ]);
    expect(
      result.splits.fold<int>(0, (sum, split) => sum + split.segmentSeconds),
      result.totalSeconds,
    );
  });

  test('incluye la meta cuando la distancia no es múltiplo del parcial', () {
    final result = calculator.calculate(
      paceSecondsPerKilometer: 240,
      distanceMeters: 1500,
      splitMeters: 400,
    );

    expect(result.splits.map((split) => split.distanceMeters), [
      400,
      800,
      1200,
      1500,
    ]);
    expect(result.splits.last.segmentMeters, 300);
    expect(result.totalSeconds, 360);
  });
}
