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

  for (final (distance, seconds) in <(double, int)>[
    (5000, 1500),
    (10000, 3000),
    (21097.5, 6329),
    (42195, 12659),
  ]) {
    test('calcula $distance m a 5:00/km sin perder la meta ni el redondeo', () {
      final result = calculator.calculate(
        paceSecondsPerKilometer: 300,
        distanceMeters: distance,
        splitMeters: 1000,
      );
      expect(result.totalSeconds, seconds);
      expect(result.splits.last.distanceMeters, distance);
      expect(
        result.splits.fold<int>(0, (sum, split) => sum + split.segmentSeconds),
        result.totalSeconds,
      );
      expect(
        result.splits.fold<double>(
          0,
          (sum, split) => sum + split.segmentMeters,
        ),
        distance,
      );
      if (distance == 21097.5) {
        expect(result.splits.last.segmentMeters, 97.5);
        expect(result.splits.last.segmentSeconds, 29);
      }
    });
  }

  test('conserva el último tramo del maratón con parciales cada 5 km', () {
    final result = calculator.calculate(
      paceSecondsPerKilometer: 300,
      distanceMeters: 42195,
      splitMeters: 5000,
    );
    expect(result.splits.length, 9);
    expect(result.splits.last.segmentMeters, 2195);
    expect(result.splits.last.segmentSeconds, 659);
    expect(result.totalSeconds, 12659);
  });

  test('admite los límites y rechaza distancias inválidas o no finitas', () {
    for (final distance in [1.0, 100000.0]) {
      expect(
        calculator
            .calculate(
              paceSecondsPerKilometer: 300,
              distanceMeters: distance,
              splitMeters: 5000,
            )
            .distanceMeters,
        distance,
      );
    }
    for (final distance in [0.0, -1.0, 100000.1, double.nan, double.infinity]) {
      expect(
        () => calculator.calculate(
          paceSecondsPerKilometer: 300,
          distanceMeters: distance,
          splitMeters: 1000,
        ),
        throwsArgumentError,
      );
    }
  });

  test('conserva los pasos de pista y usa kilómetros para carreras largas', () {
    for (final (distance, split) in <(double, int)>[
      (100, 100),
      (200, 200),
      (400, 100),
      (800, 200),
      (2000, 400),
      (3000, 1000),
      (42195, 1000),
      (100000, 1000),
    ]) {
      expect(calculator.automaticSplitMeters(distance), split);
    }
  });
}
