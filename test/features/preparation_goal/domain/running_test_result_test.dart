import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RunningTestResult result({
    int duration = 600,
    int rpe = 8,
    int? averageHr,
    int? maxHr,
    List<int>? splits,
  }) => RunningTestResult(
    completedAt: DateTime(2026, 9, 22),
    durationSeconds: duration,
    rpe: rpe,
    averageHrBpm: averageHr,
    maxHrBpm: maxHr,
    splitsSeconds: splits,
  );

  test('acepta una marca sin pulsómetro ni parciales', () {
    expect(result().validate(), isNull);
  });

  test('exige tiempo y RPE válidos', () {
    expect(result(duration: 0).validate(), isNotNull);
    expect(result(rpe: 0).validate(), isNotNull);
    expect(result(rpe: 11).validate(), isNotNull);
  });

  test('los cinco parciales deben sumar el tiempo total', () {
    expect(result(splits: [120, 120, 120, 120, 120]).validate(), isNull);
    expect(result(splits: [120, 120, 120, 120]).validate(), isNotNull);
    expect(result(splits: [120, 120, 120, 120, 119]).validate(), isNotNull);
  });

  test('la FC máxima no puede ser inferior a la media', () {
    expect(result(averageHr: 170, maxHr: 160).validate(), isNotNull);
  });
}
