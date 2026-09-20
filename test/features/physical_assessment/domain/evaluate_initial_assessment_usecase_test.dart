import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = EvaluateInitialAssessmentUseCase(AssessmentEvaluator());

  test('evalúa las cuatro marcas de ingreso con el baremo seleccionado', () {
    final report = useCase(
      category: AssessmentCategory.men,
      marks: const [
        RecordedMark(
          testId: 'upper_body_push_ups_2_min',
          unit: MarkUnit.repetitions,
          value: 9,
        ),
        RecordedMark(
          testId: 'abdominal_plank',
          unit: MarkUnit.milliseconds,
          value: 40000,
        ),
        RecordedMark(
          testId: 'run_2000_m',
          unit: MarkUnit.milliseconds,
          value: 714000,
        ),
        RecordedMark(
          testId: 'agility_speed_circuit',
          unit: MarkUnit.milliseconds,
          value: 15400,
        ),
      ],
    );

    expect(report.catalogVersion, ArmedForces2026TroopCatalog.version);
    expect(report.results, hasLength(4));
    expect(report.passedTests, 4);
    expect(report.passedOverall, isTrue);
  });

  test('rechaza una evaluación incompleta', () {
    expect(
      () => useCase(
        category: AssessmentCategory.women,
        marks: const [
          RecordedMark(
            testId: 'upper_body_push_ups_2_min',
            unit: MarkUnit.repetitions,
            value: 5,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
