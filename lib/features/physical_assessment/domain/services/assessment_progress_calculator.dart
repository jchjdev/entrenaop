import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

class AssessmentProgressCalculator {
  const AssessmentProgressCalculator();

  List<AssessmentProgress> compare({
    required PhysicalAssessmentHistoryEntry previous,
    required PhysicalAssessmentHistoryEntry current,
  }) {
    final previousByTest = {
      for (final result in previous.report.results) result.mark.testId: result,
    };

    return current.report.results
        .where((result) => previousByTest.containsKey(result.mark.testId))
        .map((result) {
          final previousResult = previousByTest[result.mark.testId]!;
          final difference = switch (result.standard.test.betterDirection) {
            BetterDirection.higher =>
              result.mark.value - previousResult.mark.value,
            BetterDirection.lower =>
              previousResult.mark.value - result.mark.value,
          };

          return AssessmentProgress(
            test: result.standard.test,
            previousValue: previousResult.mark.value,
            currentValue: result.mark.value,
            favorableDifference: difference,
          );
        })
        .toList(growable: false);
  }
}
