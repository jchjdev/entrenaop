import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reloj y milésimas conservan las unidades almacenadas', () {
    expect(parseSecondsToMilliseconds('00:30'), 30000);
    expect(parseSecondsToMilliseconds('01:30'), 90000);
    expect(parseSecondsToMilliseconds('00:15.250'), 15250);
    expect(parseSecondsToMilliseconds('00:15,250'), 15250);
    expect(parseClockToMilliseconds('00:15.250'), isNull);
    expect(parseWholeSecondsDuration('01:30'), 90000);
    expect(parseWholeSecondsDuration('00:15.250'), isNull);
  });
  test('acepta cero repeticiones como una marca válida', () {
    expect(parseRepetitions('0'), 0);
  });

  test(
    'la agilidad FAS descarta la precisión submilisegundo sin redondear',
    () {
      expect(parseFasAgilityMilliseconds('15,2999'), 15299);
      expect(parseFasAgilityMilliseconds('15.30'), 15300);
      expect(parseFasAgilityMilliseconds('15,'), 15000);
      expect(parseFasAgilityMilliseconds(',5'), 500);
      for (final invalid in [
        'Infinity',
        '0,0009',
        '-15',
        '1e3',
        '9223372036854775',
      ]) {
        expect(parseFasAgilityMilliseconds(invalid), isNull, reason: invalid);
      }
    },
  );

  test('acepta coma decimal en tiempos expresados en segundos', () {
    expect(parseSecondsToMilliseconds('15,4'), 15400);
  });

  test('convierte minutos y segundos a milisegundos', () {
    expect(parseClockToMilliseconds('11:54'), 714000);
  });

  test('rechaza segundos fuera del formato de reloj', () {
    expect(parseClockToMilliseconds('11:72'), isNull);
  });
}
