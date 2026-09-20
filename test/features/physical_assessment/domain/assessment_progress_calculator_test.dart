import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = AssessmentProgressCalculator();

  test('considera favorables más repeticiones y menos tiempo', () {
    final progress = calculator.compare(
      previous: _entry(pushUps: 10, runTime: 720000, day: 1),
      current: _entry(pushUps: 12, runTime: 710000, day: 2),
    );

    expect(progress[0].favorableDifference, 2);
    expect(progress[0].improved, isTrue);
    expect(progress[1].favorableDifference, 10000);
    expect(progress[1].improved, isTrue);
  });

  test('expresa un retroceso siempre con diferencia favorable negativa', () {
    final progress = calculator.compare(
      previous: _entry(pushUps: 12, runTime: 710000, day: 1),
      current: _entry(pushUps: 11, runTime: 715000, day: 2),
    );

    expect(progress.map((item) => item.favorableDifference), [-1, -5000]);
  });
}

PhysicalAssessmentHistoryEntry _entry({
  required int pushUps,
  required int runTime,
  required int day,
}) {
  const pushUpTest = PhysicalTestDefinition(
    id: 'push_ups',
    name: 'Flexiones',
    unit: MarkUnit.repetitions,
    betterDirection: BetterDirection.higher,
  );
  const runTest = PhysicalTestDefinition(
    id: 'run',
    name: 'Carrera',
    unit: MarkUnit.milliseconds,
    betterDirection: BetterDirection.lower,
  );

  return PhysicalAssessmentHistoryEntry(
    id: 'assessment-$day',
    completedAt: DateTime(2026, 9, day),
    report: AssessmentReport(
      catalogVersion: 'catalog',
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      results: [
        AssessmentResult(
          passed: true,
          mark: RecordedMark(
            testId: pushUpTest.id,
            unit: pushUpTest.unit,
            value: pushUps,
          ),
          standard: const AssessmentStandard(
            catalogVersion: 'catalog',
            test: pushUpTest,
            category: AssessmentCategory.men,
            milestone: AssessmentMilestone.entry,
            threshold: 9,
          ),
        ),
        AssessmentResult(
          passed: true,
          mark: RecordedMark(
            testId: runTest.id,
            unit: runTest.unit,
            value: runTime,
          ),
          standard: const AssessmentStandard(
            catalogVersion: 'catalog',
            test: runTest,
            category: AssessmentCategory.men,
            milestone: AssessmentMilestone.entry,
            threshold: 714000,
          ),
        ),
      ],
    ),
  );
}
