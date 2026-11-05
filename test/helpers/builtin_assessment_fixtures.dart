import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/data/repositories/builtin_assessment_reference_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/armed_forces_2026_troop_catalog.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:flutter/services.dart';

BuiltinAssessmentReference troopRevision({
  String id = 'troop-revision-1',
  String version = 'troop-catalog-1',
  int? entryPushUps,
}) => BuiltinAssessmentReference(
  id: id,
  programId: 'armed_forces_troop_entry',
  catalogVersion: version,
  scoringVersion: version,
  definition: {
    'schemaVersion': 1,
    'programId': 'armed_forces_troop_entry',
    'version': version,
    'name': 'Tropa para prueba',
    'description': 'Una revisión independiente',
    'sourceUrl': ArmedForces2026TroopCatalog.sourceUrl,
    'effectiveFrom': ArmedForces2026TroopCatalog.effectiveFrom,
    'tests': [
      for (final test in {
        for (final s in ArmedForces2026TroopCatalog.standards) s.test,
      })
        {
          'id': test.id,
          'name': test.name,
          'unit': test.unit.name,
          'betterDirection': test.betterDirection.name,
        },
    ],
    'standards': [
      for (final s in ArmedForces2026TroopCatalog.standards)
        {
          'testId': s.test.id,
          'category': s.category.name,
          'group': switch (s.milestone.name) {
            'entry' => 'entry',
            'endOfGeneralMilitaryTraining' =>
              'end_of_general_military_training',
            _ => 'end_of_training',
          },
          'threshold':
              s.test.id == 'upper_body_push_ups_2_min' &&
                  s.category.name == 'men' &&
                  s.milestone.name == 'entry'
              ? entryPushUps ?? s.threshold
              : s.threshold,
        },
    ],
  },
);

Future<BuiltinAssessmentReference> fasRevision({
  String id = 'fas-revision-1',
  String version = 'fas-scoring-1',
  int? pointsFor14PushUps,
}) async {
  final definition = jsonDecode(
    await rootBundle.loadString(FasPeriodic2027Reference.assetPath),
  ) as Map<String, dynamic>;
  definition['version'] = version;
  if (pointsFor14PushUps != null) {
    final test = (definition['tests'] as List).first as Map;
    final row = (test['rows'] as List).firstWhere((r) => r[0] == 14) as List;
    (row[1] as List)[0] = pointsFor14PushUps;
  }
  return BuiltinAssessmentReference(
    id: id,
    programId: 'fas_periodic_assessment',
    catalogVersion: '$version-minimums',
    scoringVersion: version,
    definition: definition,
  );
}

class MemoryBuiltinReferences implements BuiltinAssessmentReferenceRepository {
  MemoryBuiltinReferences(this.current);
  BuiltinAssessmentReference current;
  int reads = 0;
  bool fail = false;
  Object? recordError;
  String? loadedGoal;
  final records = <Map<String, dynamic>>[];

  @override
  Future<BuiltinAssessmentReference> load({
    required String programId,
    String? goalId,
    String? revisionId,
    String? scoringVersion,
  }) async {
    reads++;
    loadedGoal = goalId;
    if (fail) throw StateError('sin conexión');
    return current;
  }

  @override
  Future<String> record({
    required String revisionId,
    String? goalId,
    required String category,
    int? age,
    String? milestone,
    required Map<String, int> marks,
    DateTime? completedAt,
  }) async {
    records.add({
      'revisionId': revisionId,
      'goalId': goalId,
      'category': category,
      'age': age,
      'milestone': milestone,
      'marks': marks,
      'completedAt': completedAt,
    });
    if (recordError case final error?) throw error;
    return 'assessment-1';
  }
}
