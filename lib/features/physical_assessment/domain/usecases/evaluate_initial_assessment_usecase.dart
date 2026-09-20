import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';

class EvaluateInitialAssessmentUseCase {
  const EvaluateInitialAssessmentUseCase(this._evaluator);

  final AssessmentEvaluator _evaluator;

  AssessmentReport call({
    required AssessmentCategory category,
    required List<RecordedMark> marks,
  }) {
    // El orden es estable para que el informe siempre presente las pruebas de
    // la misma forma, aunque el cliente entregue las marcas desordenadas.
    const tests = [
      ArmedForces2026TroopCatalog.upperBodyStrength,
      ArmedForces2026TroopCatalog.abdominalPlank,
      ArmedForces2026TroopCatalog.run2000m,
      ArmedForces2026TroopCatalog.agilityCircuit,
    ];

    // Crear el mapa también permite detectar dos marcas para una misma prueba:
    // al colisionar sus claves, la longitud deja de coincidir con la entrada.
    final marksByTest = {for (final mark in marks) mark.testId: mark};
    if (marksByTest.length != tests.length || marks.length != tests.length) {
      throw ArgumentError.value(
        marks,
        'marks',
        'La evaluación inicial necesita una marca única para cada prueba.',
      );
    }

    final results = tests
        .map((test) {
          final mark = marksByTest[test.id];
          if (mark == null) {
            throw ArgumentError.value(
              marks,
              'marks',
              'Falta la marca de ${test.name}.',
            );
          }

          final standard = ArmedForces2026TroopCatalog.standardFor(
            testId: test.id,
            category: category,
            milestone: AssessmentMilestone.entry,
          );
          return _evaluator.evaluate(mark: mark, standard: standard);
        })
        .toList(growable: false);

    return AssessmentReport(
      catalogVersion: ArmedForces2026TroopCatalog.version,
      category: category,
      milestone: AssessmentMilestone.entry,
      results: results,
    );
  }
}
