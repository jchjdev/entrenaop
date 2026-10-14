import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escribe y borra cada dígito sin quedar atrapado en la máscara', () {
    const formatter = DurationInputFormatter();
    var value = const TextEditingValue();
    for (final digit in ['1', '3', '0']) {
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(text: '${value.text}$digit'),
      );
    }
    expect(value.text, '01:30');
    expect(parseDurationInput(value.text), 90);
    for (final expected in ['00:13', '00:01', '']) {
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(text: value.text.substring(0, value.text.length - 1)),
      );
      expect(value.text, expected);
    }
  });

  test('permite fracciones y coma sin perder la precisión de la marca', () {
    const formatter = DurationInputFormatter(allowFraction: true);
    expect(
      formatter
          .formatEditUpdate(
            const TextEditingValue(),
            const TextEditingValue(text: '15,250'),
          )
          .text,
      '00:15.250',
    );
    expect(
      formatter
          .formatEditUpdate(
            const TextEditingValue(),
            const TextEditingValue(text: '00:00.1234'),
          )
          .text,
      '00:00.1234',
    );
    expect(formatDurationSeconds(0.1234), '00:00.1234');
    expect(formatDurationSeconds(90), '01:30');
    expect(formatDurationSeconds(13.25), '00:13.25');
  });

  test(
    'pegar o reemplazar funciona sin necesitar un teclado con dos puntos',
    () {
      const formatter = DurationInputFormatter();
      final first = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '1130'),
      );
      expect(first.text, '11:30');
      expect(
        formatter
            .formatEditUpdate(first, const TextEditingValue(text: '45'))
            .text,
        '00:45',
      );
      expect(
        formatter
            .formatEditUpdate(first, const TextEditingValue(text: 'mal'))
            .text,
        first.text,
      );
      expect(parseDurationInput('-1:30'), isNull);
      expect(parseDurationInput('00:90'), isNull);
      expect(parseDurationInput('00:00'), 0);
    },
  );

  test('formatea dígitos como reloj sin escribir separadores', () {
    expect(formatDurationDigits('8'), '00:08');
    expect(formatDurationDigits('128'), '01:28');
    expect(formatDurationDigits('430'), '04:30');
    expect(formatDurationDigits('10205'), '01:02:05');
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
    expect(first.text, '00:03');
    final manual = formatter.formatEditUpdate(
      first,
      const TextEditingValue(text: '00:03:'),
    );
    expect(manual.text, '3:');
    final pace = formatter.formatEditUpdate(
      manual,
      const TextEditingValue(text: '3:50'),
    );
    expect(pace.text, '03:50');
    expect(parseDurationInput(pace.text), 230);
    expect(
      formatter
          .formatEditUpdate(empty, const TextEditingValue(text: '4:10'))
          .text,
      '04:10',
    );
  });
}
