import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/troop_assessment_reference.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuiltinAssessmentReference {
  const BuiltinAssessmentReference({
    required this.id,
    required this.programId,
    required this.catalogVersion,
    required this.scoringVersion,
    required this.definition,
  });
  factory BuiltinAssessmentReference.fromJson(Map<String, dynamic> row) {
    if (!['published', 'withdrawn'].contains(row['status'])) {
      throw const FormatException('La referencia no está publicada.');
    }
    for (final key in [
      'id',
      'program_id',
      'catalog_version',
      'scoring_version',
    ]) {
      if (row[key] is! String || (row[key] as String).trim().isEmpty) {
        throw const FormatException('La referencia está incompleta.');
      }
    }
    return BuiltinAssessmentReference(
      id: row['id'] as String,
      programId: row['program_id'] as String,
      catalogVersion: row['catalog_version'] as String,
      scoringVersion: row['scoring_version'] as String,
      definition: Map<String, dynamic>.from(row['definition'] as Map),
    );
  }
  final String id, programId, catalogVersion, scoringVersion;
  final Map<String, dynamic> definition;

  FasPeriodic2027Reference asFas() {
    if (programId != 'fas_periodic_assessment' ||
        definition['version'] != scoringVersion) {
      throw const FormatException('Referencia FAS incompatible.');
    }
    return FasPeriodic2027Reference.fromPublished(
      definition,
      revisionId: id,
      catalogVersion: catalogVersion,
    );
  }

  TroopAssessmentReference asTroop() {
    if (programId != 'armed_forces_troop_entry') {
      throw const FormatException('Referencia de Tropa incompatible.');
    }
    return TroopAssessmentReference.fromPublished(
      revisionId: id,
      catalogVersion: catalogVersion,
      definition: definition,
    );
  }
}

abstract interface class BuiltinAssessmentReferenceRepository {
  Future<BuiltinAssessmentReference> load({
    required String programId,
    String? goalId,
    String? revisionId,
    String? scoringVersion,
  });

  Future<String> record({
    required String revisionId,
    String? goalId,
    required String category,
    int? age,
    String? milestone,
    required Map<String, int> marks,
    DateTime? completedAt,
  });
}

class SupabaseBuiltinAssessmentReferenceRepository
    implements BuiltinAssessmentReferenceRepository {
  const SupabaseBuiltinAssessmentReferenceRepository(this.client);
  final SupabaseClient client;

  @override
  Future<BuiltinAssessmentReference> load({
    required String programId,
    String? goalId,
    String? revisionId,
    String? scoringVersion,
  }) async {
    final raw = await client
        .rpc(
          'builtin_assessment_reference',
          params: {
            'p_program_id': programId,
            'p_goal_id': goalId,
            'p_revision_id': revisionId,
            'p_scoring_version': scoringVersion,
          },
        )
        .timeout(const Duration(seconds: 15));
    final result = BuiltinAssessmentReference.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
    if (goalId == null &&
        revisionId == null &&
        scoringVersion == null &&
        raw['status'] != 'published') {
      throw const FormatException('La referencia actual está retirada.');
    }
    if (result.programId != programId ||
        (revisionId != null && result.id != revisionId) ||
        (scoringVersion != null && result.scoringVersion != scoringVersion)) {
      throw const FormatException('El servidor devolvió otra referencia.');
    }
    return result;
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
    final id = await client.rpc(
      'record_builtin_assessment',
      params: {
        'p_revision_id': revisionId,
        'p_goal_id': goalId,
        'p_category': category,
        'p_age': age,
        'p_milestone': milestone,
        'p_marks': [
          for (final entry in marks.entries)
            {'test_id': entry.key, 'value': entry.value},
        ],
        'p_completed_at': (completedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      },
    );
    if (id is! String || id.isEmpty) {
      throw const FormatException('No se pudo guardar la evaluación.');
    }
    return id;
  }
}

/// Solo el asset exacto conocido puede sustituir una lectura histórica.
/// Los fallos de otras versiones dejan su tarjeta sin puntos, nunca recalculada.
Future<Map<String, FasPeriodic2027Reference>> loadFasHistoryReferences({
  required Iterable<String> versions,
  BuiltinAssessmentReferenceRepository? repository,
  FasPeriodic2027Reference? explicitReference,
}) async {
  final result = <String, FasPeriodic2027Reference>{};
  if (explicitReference != null) {
    result[explicitReference.scoringVersion] = explicitReference;
  }
  await Future.wait(
    versions.toSet().map((version) async {
      if (result.containsKey(version)) return;
      if (version == FasPeriodic2027Reference.version) {
        result[version] = await FasPeriodic2027Reference.load();
      } else if (repository != null) {
        try {
          result[version] = (await repository.load(
            programId: 'fas_periodic_assessment',
            scoringVersion: version,
          )).asFas();
        } catch (_) {
          // Se conserva la medición y su versión aunque no se puedan leer puntos.
        }
      }
    }),
  );
  return result;
}
