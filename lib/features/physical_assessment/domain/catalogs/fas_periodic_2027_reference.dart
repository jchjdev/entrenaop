import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:flutter/services.dart';

/// Referencia de mínimos del anexo II; no es la tabla íntegra de puntos.
/// PostgreSQL conserva y valida su propia copia para el registro.
class FasPeriodic2027Reference {
  FasPeriodic2027Reference._(this._data);

  static const version = 'es_def_15_2026_periodic_2027_v1';
  static const assetPath =
      'assets/programs/fas_periodic_2027/assessment_reference_v1.json';

  final Map<String, dynamic> _data;

  static Future<FasPeriodic2027Reference> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static FasPeriodic2027Reference fromJson(Map<String, dynamic> data) {
    if (data['version'] != version ||
        data['programId'] != 'fas_periodic_assessment' ||
        data['status'] != 'draft' ||
        data['effectiveFrom'] != '2027-01-01' ||
        data['minimumPointsPerTest'] != 20) {
      throw const FormatException('Referencia periódica no válida.');
    }
    final ageBands = data['ageBands'] as List<dynamic>?;
    final tests = data['tests'] as List<dynamic>?;
    if (ageBands == null ||
        ageBands.length != 9 ||
        tests == null ||
        tests.length != 4) {
      throw const FormatException('Catálogo periódico incompleto.');
    }
    for (final rawTest in tests) {
      final test = rawTest as Map<String, dynamic>;
      final marks = test['passMarksAtLeast20Points'] as List<dynamic>?;
      final expected = test['id'] == 'agility_speed_circuit' ? 5 : 9;
      if (marks == null || marks.length != expected) {
        throw const FormatException('Faltan tramos de edad en un baremo.');
      }
      for (final rawMark in marks) {
        final mark = rawMark as Map<String, dynamic>;
        if (mark['men'] is! int ||
            mark['women'] is! int ||
            (mark['men'] as int) < 0 ||
            (mark['women'] as int) < 0) {
          throw const FormatException('Marca periódica no válida.');
        }
      }
    }
    return FasPeriodic2027Reference._(data);
  }

  /// Devuelve null si el circuito no es obligatorio para esa edad.
  /// La tabla incluye el tramo 41–45, pero el artículo 10 exige agilidad
  /// únicamente a menores de 45 años.
  PeriodicPassMark? passMarkFor({
    required String testId,
    required AssessmentCategory category,
    required int age,
  }) {
    if (age < 17) {
      throw ArgumentError.value(age, 'age', 'La tabla comienza a los 17 años.');
    }
    final tests = _data['tests'] as List<dynamic>;
    final test = tests.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['id'] == testId,
    );
    if (test['requiredBelowAge'] case final int limit when age >= limit) {
      return null;
    }
    final bands = (_data['ageBands'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final band = bands.singleWhere((item) {
      final min = item['minAge'] as int;
      final max = item['maxAge'] as int?;
      return age >= min && (max == null || age <= max);
    });
    final marks = (test['passMarksAtLeast20Points'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final values = marks.singleWhere((item) => item['ageBand'] == band['id']);
    return PeriodicPassMark(
      testId: testId,
      ageBand: band['id'] as String,
      threshold: values[category.name] as int,
      unit: MarkUnit.values.byName(test['unit'] as String),
      betterDirection: BetterDirection.values.byName(
        test['betterDirection'] as String,
      ),
    );
  }
}

class PeriodicPassMark {
  const PeriodicPassMark({
    required this.testId,
    required this.ageBand,
    required this.threshold,
    required this.unit,
    required this.betterDirection,
  });

  final String testId;
  final String ageBand;
  final int threshold;
  final MarkUnit unit;
  final BetterDirection betterDirection;

  bool meetsMinimum(int mark) => betterDirection == BetterDirection.higher
      ? mark >= threshold
      : mark <= threshold;
}
