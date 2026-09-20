import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = AssessmentEvaluator();

  group('AssessmentEvaluator', () {
    test('acepta exactamente el mínimo de una prueba de repeticiones', () {
      final standard = ArmedForces2026TroopCatalog.standardFor(
        testId: ArmedForces2026TroopCatalog.upperBodyStrength.id,
        category: AssessmentCategory.men,
        milestone: AssessmentMilestone.entry,
      );

      final result = evaluator.evaluate(
        mark: RecordedMark(
          testId: standard.test.id,
          unit: MarkUnit.repetitions,
          value: 9,
        ),
        standard: standard,
      );

      expect(result.passed, isTrue);
    });

    test('rechaza una repetición por debajo del mínimo', () {
      final standard = ArmedForces2026TroopCatalog.standardFor(
        testId: ArmedForces2026TroopCatalog.upperBodyStrength.id,
        category: AssessmentCategory.men,
        milestone: AssessmentMilestone.entry,
      );

      final result = evaluator.evaluate(
        mark: RecordedMark(
          testId: standard.test.id,
          unit: MarkUnit.repetitions,
          value: 8,
        ),
        standard: standard,
      );

      expect(result.passed, isFalse);
    });

    test('en pruebas cronometradas un tiempo menor es mejor', () {
      final standard = ArmedForces2026TroopCatalog.standardFor(
        testId: ArmedForces2026TroopCatalog.run2000m.id,
        category: AssessmentCategory.women,
        milestone: AssessmentMilestone.entry,
      );

      final result = evaluator.evaluate(
        mark: RecordedMark(
          testId: standard.test.id,
          unit: MarkUnit.milliseconds,
          value: standard.threshold - 1,
        ),
        standard: standard,
      );

      expect(result.passed, isTrue);
    });

    test('impide comparar una marca expresada en otra unidad', () {
      final standard = ArmedForces2026TroopCatalog.standardFor(
        testId: ArmedForces2026TroopCatalog.run2000m.id,
        category: AssessmentCategory.men,
        milestone: AssessmentMilestone.entry,
      );

      expect(
        () => evaluator.evaluate(
          mark: RecordedMark(
            testId: standard.test.id,
            unit: MarkUnit.repetitions,
            value: 10,
          ),
          standard: standard,
        ),
        throwsArgumentError,
      );
    });
  });

  test('el catálogo cubre las 24 combinaciones sin duplicados', () {
    final standards = ArmedForces2026TroopCatalog.standards;
    final keys = standards
        .map(
          (standard) =>
              '${standard.test.id}:${standard.category.name}:${standard.milestone.name}',
        )
        .toSet();

    expect(standards, hasLength(24));
    expect(keys, hasLength(standards.length));
  });
}
