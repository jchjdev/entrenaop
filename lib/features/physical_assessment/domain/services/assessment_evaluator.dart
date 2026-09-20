import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

class AssessmentEvaluator {
  const AssessmentEvaluator();

  AssessmentResult evaluate({
    required RecordedMark mark,
    required AssessmentStandard standard,
  }) {
    if (mark.testId != standard.test.id) {
      throw ArgumentError.value(
        mark.testId,
        'mark.testId',
        'La marca no pertenece a la prueba del baremo.',
      );
    }

    if (mark.unit != standard.test.unit) {
      throw ArgumentError.value(
        mark.unit,
        'mark.unit',
        'La unidad de la marca no coincide con la del baremo.',
      );
    }

    final passed = switch (standard.test.betterDirection) {
      BetterDirection.higher => mark.value >= standard.threshold,
      BetterDirection.lower => mark.value <= standard.threshold,
    };

    return AssessmentResult(passed: passed, mark: mark, standard: standard);
  }
}
