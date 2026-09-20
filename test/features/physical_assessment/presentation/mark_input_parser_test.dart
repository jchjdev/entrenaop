import 'package:entrenaop/features/physical_assessment/presentation/utils/mark_input_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta cero repeticiones como una marca válida', () {
    expect(parseRepetitions('0'), 0);
  });

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
