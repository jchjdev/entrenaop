import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';

import 'evolution_fixtures.dart';

PhysicalAssessmentHistoryEntry comparisonAssessment({
  int day = 6,
  int pushUps = 24,
  int plank = 90000,
  int run = 530000,
  String version = 'ingreso-v1',
  AssessmentCategory category = AssessmentCategory.men,
  AssessmentMilestone milestone = AssessmentMilestone.entry,
  MarkUnit pushUpUnit = MarkUnit.repetitions,
  BetterDirection pushUpDirection = BetterDirection.higher,
}) => PhysicalAssessmentHistoryEntry(
  id: 'assessment-$day',
  completedAt: DateTime(2026, 10, day, 9),
  report: AssessmentReport(
    catalogVersion: version,
    category: category,
    milestone: milestone,
    results: [
      for (final item in [
        (
          'upper_body_push_ups_2_min',
          'Flexo-extensiones (2 min)',
          pushUpUnit,
          pushUpDirection,
          pushUps,
        ),
        (
          'abdominal_plank',
          'Plancha isométrica',
          MarkUnit.milliseconds,
          BetterDirection.higher,
          plank,
        ),
        (
          'run_2000_m',
          'Carrera de 2 km',
          MarkUnit.milliseconds,
          BetterDirection.lower,
          run,
        ),
      ])
        AssessmentResult(
          passed: true,
          mark: RecordedMark(testId: item.$1, unit: item.$3, value: item.$5),
          standard: AssessmentStandard(
            catalogVersion: version,
            test: PhysicalTestDefinition(
              id: item.$1,
              name: item.$2,
              unit: item.$3,
              betterDirection: item.$4,
            ),
            category: category,
            milestone: milestone,
            threshold: 10,
          ),
        ),
    ],
  ),
);

PreparationMarksData comparisonMarksData({bool newResult = false}) =>
    PreparationMarksData(
      goal: evolutionTroop,
      troop: [
        if (newResult) comparisonAssessment(day: 7, pushUps: 26),
        comparisonAssessment(),
        comparisonAssessment(day: 3, pushUps: 22, plank: 90000, run: 550000),
        comparisonAssessment(day: 1, pushUps: 18, plank: 60000, run: 540000),
      ],
      running: [
        RunningTestResult(
          id: 'control-6',
          completedAt: DateTime(2026, 10, 6, 18),
          durationSeconds: 520,
          rpe: 8,
        ),
        RunningTestResult(
          id: 'control-1',
          completedAt: DateTime(2026, 10, 1, 18),
          durationSeconds: 540,
          rpe: 7,
        ),
      ],
    );
