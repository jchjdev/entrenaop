import 'package:entrenaop/features/physical_assessment/data/models/physical_assessment_history_model.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agrupa las filas de la vista y ordena la evaluación más reciente', () {
    final entries = PhysicalAssessmentHistoryModel.fromRows([
      _row(assessmentId: 'old', completedAt: '2026-09-18T10:00:00Z'),
      _row(
        assessmentId: 'new',
        completedAt: '2026-09-20T10:00:00Z',
        testId: 'abdominal_plank',
        testName: 'Plancha',
        value: 45000,
        threshold: 40000,
        direction: 'higher',
      ),
      _row(assessmentId: 'new', completedAt: '2026-09-20T10:00:00Z'),
    ]);

    expect(entries.map((entry) => entry.id), ['new', 'old']);
    expect(entries.first.report.results, hasLength(2));
    expect(entries.first.report.results.map((result) => result.mark.testId), [
      'upper_body_push_ups_2_min',
      'abdominal_plank',
    ]);
    expect(entries.first.report.category, AssessmentCategory.men);
    expect(entries.first.report.passedOverall, isTrue);
    expect(
      entries.first.recommendation,
      const AssessmentFocusRecommendation(
        algorithmVersion: 'assessment_focus_v1',
        focusTestId: 'upper_body_push_ups_2_min',
        relativeMarginBps: -4444,
        reason: AssessmentFocusReason.belowMinimum,
      ),
    );
  });
}

Map<String, dynamic> _row({
  required String assessmentId,
  required String completedAt,
  String testId = 'upper_body_push_ups_2_min',
  String testName = 'Flexiones',
  int value = 10,
  int threshold = 9,
  String direction = 'higher',
}) {
  return {
    'assessment_id': assessmentId,
    'completed_at': completedAt,
    'catalog_version': 'catalog-v1',
    'category': 'men',
    'milestone': 'entry',
    'test_id': testId,
    'test_name': testName,
    'unit': testId == 'abdominal_plank' ? 'milliseconds' : 'repetitions',
    'better_direction': direction,
    'value': value,
    'threshold': threshold,
    'passed': true,
    'recommendation_algorithm_version': 'assessment_focus_v1',
    'recommendation_focus_test_id': 'upper_body_push_ups_2_min',
    'recommendation_relative_margin_bps': -4444,
    'recommendation_reason': 'below_minimum',
  };
}
