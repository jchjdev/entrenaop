import 'package:entrenaop/features/preparation_goal/domain/entities/two_kilometre_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('11:00 a 7:30 muestra la magnitud real sin autorizar ese ritmo', () {
    final current = TwoKilometrePerformance.fromSeconds(660)!;
    final target = TwoKilometrePerformance.fromSeconds(450)!;

    expect(current.speedMetersPerSecond, closeTo(3.0303, 0.0001));
    expect(current.paceSecondsPerKilometre, 330);
    expect(target.paceSecondsPerKilometre, 225);
    expect(current.speedGapTo(target), closeTo(0.466667, 0.000001));
  });

  test('el objetivo igual o más lento no se interpreta como mejora', () {
    final current = TwoKilometrePerformance.fromSeconds(480)!;
    expect(current.speedGapTo(current), 0);
    expect(
      current.speedGapTo(TwoKilometrePerformance.fromSeconds(500)!),
      lessThan(0),
    );
  });

  test('rechaza datos fuera del contrato del test de 2 km', () {
    for (final seconds in [null, 0, -1, 119, 7201]) {
      expect(TwoKilometrePerformance.fromSeconds(seconds), isNull);
    }
  });
}
