import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

String formatAssessmentValue(int value, PhysicalTestDefinition test) {
  if (test.unit == MarkUnit.repetitions) return '$value rep';
  if (test.id == ArmedForces2026TroopCatalog.run2000m.id) {
    final totalSeconds = value ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  final seconds = value / 1000;
  final decimals = value % 1000 == 0 ? 0 : 1;
  return '${seconds.toStringAsFixed(decimals).replaceAll('.', ',')} s';
}

String formatAssessmentDifference(int value, MarkUnit unit) {
  if (unit == MarkUnit.repetitions) return '$value rep';
  final seconds = value / 1000;
  final decimals = value % 1000 == 0 ? 0 : 1;
  return '${seconds.toStringAsFixed(decimals).replaceAll('.', ',')} s';
}

String formatAssessmentDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} · '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
