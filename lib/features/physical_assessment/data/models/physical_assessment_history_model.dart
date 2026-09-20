import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

abstract final class PhysicalAssessmentHistoryModel {
  static List<PhysicalAssessmentHistoryEntry> fromRows(
    List<Map<String, dynamic>> rows,
  ) {
    final groupedRows = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final assessmentId = row['assessment_id'] as String;
      groupedRows.putIfAbsent(assessmentId, () => []).add(row);
    }

    final entries = groupedRows.values.map(_entryFromRows).toList();
    entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return entries;
  }

  static PhysicalAssessmentHistoryEntry _entryFromRows(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      throw const FormatException('Una evaluación debe contener marcas.');
    }

    final header = rows.first;
    final orderedRows = [...rows]
      ..sort(
        (a, b) => _testOrder(
          a['test_id'] as String,
        ).compareTo(_testOrder(b['test_id'] as String)),
      );
    final results = orderedRows.map(_resultFromRow).toList(growable: false);

    return PhysicalAssessmentHistoryEntry(
      id: header['assessment_id'] as String,
      completedAt: DateTime.parse(header['completed_at'] as String).toLocal(),
      recommendation: _recommendationFromRow(header),
      report: AssessmentReport(
        catalogVersion: header['catalog_version'] as String,
        category: _categoryFromDatabase(header['category'] as String),
        milestone: _milestoneFromDatabase(header['milestone'] as String),
        results: results,
      ),
    );
  }

  static AssessmentResult _resultFromRow(Map<String, dynamic> row) {
    final unit = _unitFromDatabase(row['unit'] as String);
    final test = PhysicalTestDefinition(
      id: row['test_id'] as String,
      name: row['test_name'] as String,
      unit: unit,
      betterDirection: _directionFromDatabase(
        row['better_direction'] as String,
      ),
    );

    return AssessmentResult(
      passed: row['passed'] as bool,
      mark: RecordedMark(
        testId: test.id,
        unit: unit,
        value: (row['value'] as num).toInt(),
      ),
      standard: AssessmentStandard(
        catalogVersion: row['catalog_version'] as String,
        test: test,
        category: _categoryFromDatabase(row['category'] as String),
        milestone: _milestoneFromDatabase(row['milestone'] as String),
        threshold: (row['threshold'] as num).toInt(),
      ),
    );
  }

  static AssessmentCategory _categoryFromDatabase(String value) =>
      switch (value) {
        'men' => AssessmentCategory.men,
        'women' => AssessmentCategory.women,
        _ => throw FormatException('Categoría desconocida: $value'),
      };

  static AssessmentMilestone _milestoneFromDatabase(String value) =>
      switch (value) {
        'entry' => AssessmentMilestone.entry,
        'end_of_general_military_training' =>
          AssessmentMilestone.endOfGeneralMilitaryTraining,
        'end_of_training' => AssessmentMilestone.endOfTraining,
        _ => throw FormatException('Hito desconocido: $value'),
      };

  static MarkUnit _unitFromDatabase(String value) => switch (value) {
    'repetitions' => MarkUnit.repetitions,
    'milliseconds' => MarkUnit.milliseconds,
    _ => throw FormatException('Unidad desconocida: $value'),
  };

  static BetterDirection _directionFromDatabase(String value) =>
      switch (value) {
        'higher' => BetterDirection.higher,
        'lower' => BetterDirection.lower,
        _ => throw FormatException('Dirección desconocida: $value'),
      };

  static AssessmentFocusRecommendation? _recommendationFromRow(
    Map<String, dynamic> row,
  ) {
    final algorithmVersion = row['recommendation_algorithm_version'] as String?;
    if (algorithmVersion == null) return null;

    return AssessmentFocusRecommendation(
      algorithmVersion: algorithmVersion,
      focusTestId: row['recommendation_focus_test_id'] as String,
      relativeMarginBps: (row['recommendation_relative_margin_bps'] as num)
          .toInt(),
      reason: switch (row['recommendation_reason'] as String) {
        'below_minimum' => AssessmentFocusReason.belowMinimum,
        'smallest_safety_margin' => AssessmentFocusReason.smallestSafetyMargin,
        final value => throw FormatException(
          'Motivo de recomendación desconocido: $value',
        ),
      },
    );
  }

  static int _testOrder(String testId) => switch (testId) {
    'upper_body_push_ups_2_min' => 0,
    'abdominal_plank' => 1,
    'run_2000_m' => 2,
    'agility_speed_circuit' => 3,
    _ => 100,
  };
}
