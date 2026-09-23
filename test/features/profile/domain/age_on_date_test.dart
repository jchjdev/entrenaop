import 'package:entrenaop/features/profile/domain/age_on_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el cumpleaños cambia de tramo justo ese día', () {
    final birthDate = DateTime(1981, 9, 24);
    expect(ageOnDate(birthDate, DateTime(2026, 9, 23)), 44);
    expect(ageOnDate(birthDate, DateTime(2026, 9, 24)), 45);
  });

  test('un 29 de febrero cumple años el 1 de marzo cuando no es bisiesto', () {
    final birthDate = DateTime(1980, 2, 29);
    expect(ageOnDate(birthDate, DateTime(2026, 2, 28)), 45);
    expect(ageOnDate(birthDate, DateTime(2026, 3, 1)), 46);
  });
}
