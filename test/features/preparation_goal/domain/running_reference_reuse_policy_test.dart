import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_reuse_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = RunningReferenceReusePolicy();
  final now = DateTime(2026, 9, 30, 12);

  test('el día 30 aún permite sugerir y el 31 exige revisar continuidad', () {
    expect(
      policy.assess(measuredAt: DateTime(2026, 8, 31, 8), now: now).window,
      RunningReferenceReuseWindow.recent,
    );
    expect(
      policy.assess(measuredAt: DateTime(2026, 8, 30, 8), now: now).window,
      RunningReferenceReuseWindow.conditional,
    );
  });

  test('el día 45 es condicional y el 46 ya no sirve de referencia', () {
    expect(
      policy.assess(measuredAt: DateTime(2026, 8, 16), now: now).window,
      RunningReferenceReuseWindow.conditional,
    );
    expect(
      policy.assess(measuredAt: DateTime(2026, 8, 15), now: now).window,
      RunningReferenceReuseWindow.expired,
    );
  });

  test('una fecha futura se rechaza incluso si es el mismo día', () {
    expect(
      policy.assess(measuredAt: DateTime(2026, 9, 30, 13), now: now).window,
      RunningReferenceReuseWindow.futureDate,
    );
  });

  test('el cambio de hora no acorta la ventana por horas transcurridas', () {
    final result = policy.assess(
      measuredAt: DateTime(2026, 3, 29, 8),
      now: DateTime(2026, 4, 28, 8),
    );
    expect(result.daysOld, 30);
    expect(result.window, RunningReferenceReuseWindow.recent);
  });
}
