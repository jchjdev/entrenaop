import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

/// Una definición fijada para todo el formulario, no un enlace a «la actual».
class TroopAssessmentReference {
  const TroopAssessmentReference({
    required this.catalogVersion,
    required this.standards,
    this.revisionId,
  });

  factory TroopAssessmentReference.legacy() => const TroopAssessmentReference(
    catalogVersion: ArmedForces2026TroopCatalog.version,
    standards: ArmedForces2026TroopCatalog.standards,
  );

  factory TroopAssessmentReference.fromPublished({
    required String revisionId,
    required String catalogVersion,
    required Map<String, dynamic> definition,
  }) {
    if (definition['schemaVersion'] != 1 ||
        definition['programId'] != 'armed_forces_troop_entry' ||
        revisionId.isEmpty ||
        catalogVersion.isEmpty) {
      throw const FormatException('Definición de Tropa no compatible.');
    }
    final tests = <String, PhysicalTestDefinition>{};
    for (final raw in definition['tests'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final test = PhysicalTestDefinition(
        id: row['id'] as String,
        name: row['name'] as String,
        unit: MarkUnit.values.byName(row['unit'] as String),
        betterDirection: BetterDirection.values.byName(
          row['betterDirection'] as String,
        ),
      );
      final seed = ArmedForces2026TroopCatalog.standards
          .where((s) => s.test.id == test.id)
          .firstOrNull
          ?.test;
      if (seed == null ||
          seed.unit != test.unit ||
          seed.betterDirection != test.betterDirection ||
          tests.containsKey(test.id)) {
        throw const FormatException('El protocolo de Tropa no es compatible.');
      }
      tests[test.id] = test;
    }
    if (tests.length != 4) {
      throw const FormatException('Faltan pruebas de Tropa.');
    }
    final standards = <AssessmentStandard>[];
    final keys = <String>{};
    for (final raw in definition['standards'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final test = tests[row['testId']];
      final group = switch (row['group']) {
        'entry' => AssessmentMilestone.entry,
        'end_of_general_military_training' =>
          AssessmentMilestone.endOfGeneralMilitaryTraining,
        'end_of_training' => AssessmentMilestone.endOfTraining,
        _ => throw const FormatException('Hito de Tropa no compatible.'),
      };
      final category = AssessmentCategory.values.byName(
        row['category'] as String,
      );
      final value = row['threshold'];
      if (test == null ||
          value is! int ||
          value < 0 ||
          !keys.add('${test.id}/${category.name}/${group.name}')) {
        throw const FormatException('Mínimo de Tropa no válido.');
      }
      standards.add(
        AssessmentStandard(
          catalogVersion: catalogVersion,
          test: test,
          category: category,
          milestone: group,
          threshold: value,
        ),
      );
    }
    if (standards.length != 24) {
      throw const FormatException('Baremo de Tropa incompleto.');
    }
    return TroopAssessmentReference(
      revisionId: revisionId,
      catalogVersion: catalogVersion,
      standards: List.unmodifiable(standards),
    );
  }

  final String? revisionId;
  final String catalogVersion;
  final List<AssessmentStandard> standards;

  AssessmentStandard standardFor({
    required String testId,
    required AssessmentCategory category,
    required AssessmentMilestone milestone,
  }) => standards.singleWhere(
    (s) =>
        s.test.id == testId &&
        s.category == category &&
        s.milestone == milestone,
  );
}
