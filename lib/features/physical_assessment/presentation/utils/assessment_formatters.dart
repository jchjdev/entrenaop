import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

String formatAssessmentValue(int value, PhysicalTestDefinition test) {
  if (test.unit == MarkUnit.repetitions) return '$value rep';
  if (test.id == ArmedForces2026TroopCatalog.run2000m.id) {
    final totalSeconds = value ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final fraction = value % 1000;
    final suffix = fraction == 0 ? '' : ',${_fraction(fraction)}';
    return '$minutes:${seconds.toString().padLeft(2, '0')}$suffix';
  }

  final seconds = value / 1000;
  final decimals = _decimals(value);
  return '${seconds.toStringAsFixed(decimals).replaceAll('.', ',')} s';
}

String formatAssessmentDifference(int value, MarkUnit unit) {
  if (unit == MarkUnit.repetitions) return '$value rep';
  final seconds = value / 1000;
  final decimals = _decimals(value);
  return '${seconds.toStringAsFixed(decimals).replaceAll('.', ',')} s';
}

// La comparación debe conservar la precisión guardada, incluidas centésimas
// o milésimas; redondear aquí puede ocultar una diferencia entre dos registros.
int _decimals(int milliseconds) => milliseconds % 1000 == 0
    ? 0
    : milliseconds % 100 == 0
    ? 1
    : milliseconds % 10 == 0
    ? 2
    : 3;

String _fraction(int milliseconds) =>
    milliseconds.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');

String formatAssessmentDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} · '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
