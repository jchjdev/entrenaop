import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

abstract final class ArmedForces2026TroopCatalog {
  static const version = 'es_def_15_2026_troop_v1';
  static const effectiveFrom = '2026-01-22';
  static const sourceUrl = 'https://www.boe.es/eli/es/o/2026/01/13/def15';

  static const upperBodyStrength = PhysicalTestDefinition(
    id: 'upper_body_push_ups_2_min',
    name: 'Flexo-extensiones de brazos (2 min)',
    unit: MarkUnit.repetitions,
    betterDirection: BetterDirection.higher,
  );

  static const abdominalPlank = PhysicalTestDefinition(
    id: 'abdominal_plank',
    name: 'Plancha isométrica',
    unit: MarkUnit.milliseconds,
    betterDirection: BetterDirection.higher,
  );

  static const run2000m = PhysicalTestDefinition(
    id: 'run_2000_m',
    name: 'Carrera continua de 2.000 m',
    unit: MarkUnit.milliseconds,
    betterDirection: BetterDirection.lower,
  );

  static const agilityCircuit = PhysicalTestDefinition(
    id: 'agility_speed_circuit',
    name: 'Circuito de agilidad-velocidad',
    unit: MarkUnit.milliseconds,
    betterDirection: BetterDirection.lower,
  );

  static const standards = <AssessmentStandard>[
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      threshold: 9,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 13,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 15,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.entry,
      threshold: 5,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 7,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: upperBodyStrength,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 8,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      threshold: 40000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 44000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 48000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.entry,
      threshold: 40000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 44000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: abdominalPlank,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 48000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      threshold: 714000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 706000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 690000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.entry,
      threshold: 778000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 762000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: run2000m,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 754000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.entry,
      threshold: 15400,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 15200,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.men,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 15000,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.entry,
      threshold: 17100,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfGeneralMilitaryTraining,
      threshold: 16900,
    ),
    AssessmentStandard(
      catalogVersion: version,
      test: agilityCircuit,
      category: AssessmentCategory.women,
      milestone: AssessmentMilestone.endOfTraining,
      threshold: 16700,
    ),
  ];

  static AssessmentStandard standardFor({
    required String testId,
    required AssessmentCategory category,
    required AssessmentMilestone milestone,
  }) => standards.singleWhere(
    (standard) =>
        standard.test.id == testId &&
        standard.category == category &&
        standard.milestone == milestone,
  );
}
