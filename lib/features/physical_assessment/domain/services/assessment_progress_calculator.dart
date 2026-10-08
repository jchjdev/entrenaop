import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

class AssessmentProgressCalculator {
  const AssessmentProgressCalculator();

  List<AssessmentProgress> compare({
    required PhysicalAssessmentHistoryEntry previous,
    required PhysicalAssessmentHistoryEntry current,
  }) {
    if (!previous.completedAt.isBefore(current.completedAt) ||
        previous.report.catalogVersion.trim().isEmpty ||
        previous.report.catalogVersion != current.report.catalogVersion ||
        previous.report.category != current.report.category ||
        previous.report.milestone != current.report.milestone) {
      return const [];
    }
    final previousByTest = {
      for (final result in previous.report.results) result.mark.testId: result,
    };

    return current.report.results
        .where((result) {
          final before = previousByTest[result.mark.testId];
          if (before == null) return false;
          final oldTest = before.standard.test;
          final newTest = result.standard.test;
          return oldTest.id == newTest.id &&
              oldTest.unit == newTest.unit &&
              oldTest.betterDirection == newTest.betterDirection &&
              before.mark.unit == oldTest.unit &&
              result.mark.unit == newTest.unit &&
              result.mark.testId == newTest.id &&
              before.mark.testId == oldTest.id &&
              before.standard.catalogVersion ==
                  previous.report.catalogVersion &&
              result.standard.catalogVersion == current.report.catalogVersion &&
              before.standard.category == previous.report.category &&
              result.standard.category == current.report.category &&
              before.standard.milestone == previous.report.milestone &&
              result.standard.milestone == current.report.milestone;
        })
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
