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

  test('permite escribir dos puntos sin perder el autoformato numérico', () {
    const formatter = DurationInputFormatter();
    const empty = TextEditingValue();
    final first = formatter.formatEditUpdate(
      empty,
      const TextEditingValue(text: '3'),
    );
    expect(first.text, '0:03');
    final manual = formatter.formatEditUpdate(
      first,
      const TextEditingValue(text: '0:03:'),
    );
    expect(manual.text, '3:');
    final pace = formatter.formatEditUpdate(
      manual,
      const TextEditingValue(text: '3:50'),
    );
    expect(pace.text, '3:50');
    expect(parseDurationInput(pace.text), 230);
    expect(
      formatter
          .formatEditUpdate(empty, const TextEditingValue(text: '4:10'))
          .text,
      '4:10',
    );
  });
}
