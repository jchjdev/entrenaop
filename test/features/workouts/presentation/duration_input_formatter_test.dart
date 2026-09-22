import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea dígitos como reloj sin escribir separadores', () {
    expect(formatDurationDigits('8'), '0:08');
    expect(formatDurationDigits('128'), '1:28');
    expect(formatDurationDigits('430'), '4:30');
    expect(formatDurationDigits('10205'), '1:02:05');
  });

  test('convierte el reloj asistido a segundos', () {
    expect(parseDurationInput('1:28'), 88);
    expect(parseDurationInput('1:02:05'), 3725);
    expect(parseDurationInput('1:99'), isNull);
  });
}
