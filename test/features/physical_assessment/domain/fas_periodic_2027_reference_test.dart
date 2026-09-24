import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FasPeriodic2027Reference reference;
  setUpAll(() async {
    reference = await FasPeriodic2027Reference.load();
  });

  test('lee mínimos del anexo II sin reutilizar el baremo de ingreso', () {
    expect(
      FasPeriodic2027Reference.version,
      'es_def_15_2026_periodic_2027_v2_full_scores',
    );
    expect(
      reference
          .passMarkFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.men,
            age: 25,
          )!
          .threshold,
      14,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.women,
            age: 25,
          )!
          .threshold,
      8,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 30,
          )!
          .threshold,
      714000,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'abdominal_plank',
            category: AssessmentCategory.women,
            age: 60,
          )!
          .threshold,
      28000,
    );
  });

  test('respeta el sentido de cada marca y el límite de edad de agilidad', () {
    final run = reference.passMarkFor(
      testId: 'run_2000_m',
      category: AssessmentCategory.women,
      age: 24,
    )!;
    expect(run.threshold, 754000);
    expect(run.meetsMinimum(754000), isTrue);
    expect(run.meetsMinimum(755000), isFalse);

    final agility = reference.passMarkFor(
      testId: 'agility_speed_circuit',
      category: AssessmentCategory.men,
      age: 44,
    )!;
    expect(agility.threshold, 16200);
    expect(
      reference.passMarkFor(
        testId: 'agility_speed_circuit',
        category: AssessmentCategory.men,
        age: 45,
      ),
      isNull,
    );
  });

  test('calcula puntos exactos y el intervalo conservador entre filas', () {
    expect(
      reference.scoreFor(
        testId: 'upper_body_push_ups_2_min',
        category: AssessmentCategory.men,
        age: 25,
        mark: 73,
      )!.points,
      100,
    );
    expect(
      reference.scoreFor(
        testId: 'upper_body_push_ups_2_min',
        category: AssessmentCategory.men,
        age: 25,
        mark: 14,
      )!.points,
      20,
    );
    expect(
      reference.scoreFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 25,
        mark: 706000,
      )!.points,
      20,
    );
    expect(
      reference.scoreFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 25,
        mark: 707000,
      )!.points,
      19,
    );
  });

  test('aplica columnas por sexo y tramo sin extrapolar', () {
    expect(
      reference.scoreFor(
        testId: 'upper_body_push_ups_2_min',
        category: AssessmentCategory.women,
        age: 25,
        mark: 14,
      )!.points,
      26,
    );
    expect(
      reference.scoreFor(
        testId: 'upper_body_push_ups_2_min',
        category: AssessmentCategory.men,
        age: 26,
        mark: 14,
      )!.points,
      21,
    );
    expect(
      reference.scoreFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 25,
        mark: 300000,
      )!.points,
      100,
    );
    expect(
      reference.scoreFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 25,
        mark: 1200000,
      )!.points,
      0,
    );
  });

  test('elimina centésimas de agilidad y corta al cumplir 45', () {
    final result = reference.scoreFor(
      testId: 'agility_speed_circuit',
      category: AssessmentCategory.men,
      age: 44,
      mark: 16299,
    )!;
    expect(result.scoredMark, 16200);
    expect(result.points, 20);
    expect(
      reference.scoreFor(
        testId: 'agility_speed_circuit',
        category: AssessmentCategory.men,
        age: 45,
        mark: 16200,
      ),
      isNull,
    );
  });

  test('rechaza edades fuera del catálogo', () {
    expect(
      () => reference.passMarkFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 16,
      ),
      throwsArgumentError,
    );
  });
}
