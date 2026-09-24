import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/fas_periodic_score_calculator.dart';
import 'package:flutter/services.dart';

/// Catálogo íntegro y versionado del anexo II de la Orden DEF/15/2026.
///
/// El registro histórico conserva su versión de mínimos en PostgreSQL. Este
/// catálogo local se usa para calcular puntos sin guardar ni alterar intentos.
class FasPeriodic2027Reference {
  FasPeriodic2027Reference._(this._data, this._tables);

  static const version = 'es_def_15_2026_periodic_2027_v2_full_scores';
  static const assetPath =
      'assets/programs/fas_periodic_2027/assessment_reference_v1.json';
  static const sourceUrl = 'https://www.boe.es/eli/es/o/2026/01/13/def15';
  static const effectiveFrom = '2027-01-01';

  final Map<String, dynamic> _data;
  final Map<String, _ScoreTable> _tables;

  static Future<FasPeriodic2027Reference> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static FasPeriodic2027Reference fromJson(Map<String, dynamic> data) {
    if (data['version'] != version ||
        data['programId'] != 'fas_periodic_assessment' ||
        data['status'] != 'future_reference' ||
        data['effectiveFrom'] != effectiveFrom ||
        data['sourceUrl'] != sourceUrl ||
        data['minimumPointsPerTest'] != 20) {
      throw const FormatException('Catálogo periódico no válido.');
    }

    final ageBands = _parseAgeBands(data['ageBands']);
    final rawTests = data['tests'] as List<dynamic>?;
    if (rawTests == null || rawTests.length != 4) {
      throw const FormatException('Catálogo periódico incompleto.');
    }

    final tables = <String, _ScoreTable>{};
    for (final raw in rawTests) {
      final test = raw as Map<String, dynamic>;
      final id = test['id'] as String?;
      final expectedRows = _expectedRows[id];
      if (id == null || expectedRows == null || tables.containsKey(id)) {
        throw const FormatException('Prueba periódica no válida.');
      }

      final testBands = test['ageBands'] == null
          ? ageBands.map((band) => band.id).toList(growable: false)
          : (test['ageBands'] as List<dynamic>).cast<String>();
      if (testBands.isEmpty ||
          testBands.any((id) => !ageBands.any((band) => band.id == id))) {
        throw const FormatException('Tramos de edad no válidos.');
      }

      final categoriesPerBand = test['categoriesPerAgeBand'] as bool?;
      final rows = test['rows'] as List<dynamic>?;
      final expectedScores =
          testBands.length * (categoriesPerBand == true ? 2 : 1);
      if (categoriesPerBand == null ||
          rows == null ||
          rows.length != expectedRows) {
        throw const FormatException('Tabla de puntos incompleta.');
      }

      final parsedRows = <_ScoreRow>[];
      for (final rawRow in rows) {
        final row = rawRow as List<dynamic>;
        if (row.length != 2 || row[0] is! int || row[1] is! List<dynamic>) {
          throw const FormatException('Fila de puntuación no válida.');
        }
        final scores = row[1] as List<dynamic>;
        if (scores.length != expectedScores ||
            scores.any((score) => score is! int || score < 0 || score > 100)) {
          throw const FormatException('Puntuaciones no válidas.');
        }
        parsedRows.add(
          _ScoreRow(mark: row[0] as int, scores: scores.cast<int>()),
        );
      }

      final direction = BetterDirection.values.byName(
        test['betterDirection'] as String,
      );
      if (parsedRows.map((row) => row.mark).toSet().length !=
          parsedRows.length) {
        throw const FormatException('Hay marcas duplicadas.');
      }

      tables[id] = _ScoreTable(
        testId: id,
        unit: MarkUnit.values.byName(test['unit'] as String),
        direction: direction,
        requiredBelowAge: test['requiredBelowAge'] as int?,
        ageBands: testBands,
        categoriesPerAgeBand: categoriesPerBand,
        rows: parsedRows,
      );
    }
    return FasPeriodic2027Reference._(data, tables);
  }

  String get verifiedOn => _data['verifiedOn'] as String;

  /// Devuelve null cuando la prueba no es exigible para la edad indicada.
  PeriodicScoreResult? scoreFor({
    required String testId,
    required AssessmentCategory category,
    required int age,
    required int mark,
  }) {
    final table = _tableFor(testId, age);
    if (table == null) return null;
    final band = _ageBandFor(age);
    final column = table.columnFor(band.id, category);
    final scale = FasPeriodicScoreScale(
      testId: testId,
      betterDirection: table.direction,
      thresholds: [
        for (final row in table.rows)
          FasPeriodicScoreThreshold(mark: row.mark, points: row.scores[column]),
      ],
      // El anexo I ordena eliminar las centésimas en agilidad.
      markResolution: testId == 'agility_speed_circuit' ? 100 : 1,
    );
    final calculation = const FasPeriodicScoreCalculator().calculate(
      scale: scale,
      mark: mark,
    );
    return PeriodicScoreResult(
      testId: testId,
      ageBand: band.id,
      rawMark: mark,
      scoredMark: calculation.scoredMark,
      points: calculation.points,
      unit: table.unit,
      meetsMinimum: calculation.points >= 20,
    );
  }

  PeriodicPassMark? passMarkFor({
    required String testId,
    required AssessmentCategory category,
    required int age,
  }) {
    final table = _tableFor(testId, age);
    if (table == null) return null;
    final band = _ageBandFor(age);
    final column = table.columnFor(band.id, category);
    final passing = [
      for (final row in table.rows)
        if (row.scores[column] >= 20) row.mark,
    ];
    final threshold = table.direction == BetterDirection.higher
        ? passing.reduce((a, b) => a < b ? a : b)
        : passing.reduce((a, b) => a > b ? a : b);
    return PeriodicPassMark(
      testId: testId,
      ageBand: band.id,
      threshold: threshold,
      unit: table.unit,
      betterDirection: table.direction,
    );
  }

  _ScoreTable? _tableFor(String testId, int age) {
    _ageBandFor(age);
    final table = _tables[testId];
    if (table == null) throw ArgumentError.value(testId, 'testId');
    if (table.requiredBelowAge case final limit? when age >= limit) return null;
    return table;
  }

  _AgeBand _ageBandFor(int age) {
    if (age < 17 || age > 120) {
      throw ArgumentError.value(age, 'age', 'Edad fuera del baremo.');
    }
    final bands = _parseAgeBands(_data['ageBands']);
    return bands.singleWhere(
      (band) =>
          age >= band.minAge && (band.maxAge == null || age <= band.maxAge!),
    );
  }
}

const _expectedRows = <String, int>{
  'upper_body_push_ups_2_min': 74,
  'abdominal_plank': 84,
  'run_2000_m': 73,
  'agility_speed_circuit': 75,
};

List<_AgeBand> _parseAgeBands(Object? raw) {
  final values = raw as List<dynamic>?;
  if (values == null || values.length != 9) {
    throw const FormatException('Tramos de edad incompletos.');
  }
  return [
    for (final value in values)
      _AgeBand(
        id: (value as Map<String, dynamic>)['id'] as String,
        minAge: value['minAge'] as int,
        maxAge: value['maxAge'] as int?,
      ),
  ];
}

class _AgeBand {
  const _AgeBand({required this.id, required this.minAge, this.maxAge});
  final String id;
  final int minAge;
  final int? maxAge;
}

class _ScoreTable {
  const _ScoreTable({
    required this.testId,
    required this.unit,
    required this.direction,
    required this.requiredBelowAge,
    required this.ageBands,
    required this.categoriesPerAgeBand,
    required this.rows,
  });

  final String testId;
  final MarkUnit unit;
  final BetterDirection direction;
  final int? requiredBelowAge;
  final List<String> ageBands;
  final bool categoriesPerAgeBand;
  final List<_ScoreRow> rows;

  int columnFor(String ageBand, AssessmentCategory category) {
    final bandIndex = ageBands.indexOf(ageBand);
    if (bandIndex < 0) throw StateError('Tramo no disponible para $testId.');
    if (!categoriesPerAgeBand) return bandIndex;
    return bandIndex * 2 + (category == AssessmentCategory.men ? 0 : 1);
  }
}

class _ScoreRow {
  const _ScoreRow({required this.mark, required this.scores});
  final int mark;
  final List<int> scores;
}

class PeriodicScoreResult {
  const PeriodicScoreResult({
    required this.testId,
    required this.ageBand,
    required this.rawMark,
    required this.scoredMark,
    required this.points,
    required this.unit,
    required this.meetsMinimum,
  });

  final String testId;
  final String ageBand;
  final int rawMark;
  final int scoredMark;
  final int points;
  final MarkUnit unit;
  final bool meetsMinimum;
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
