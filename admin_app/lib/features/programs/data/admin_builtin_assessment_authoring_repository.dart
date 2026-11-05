import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> copyBuiltinDefinition(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

class AdminBuiltinAssessmentRevision {
  const AdminBuiltinAssessmentRevision({
    required this.id,
    required this.programId,
    required this.revision,
    required this.status,
    required this.definition,
    required this.catalogVersion,
    required this.scoringVersion,
    required this.editVersion,
    required this.changeReason,
    this.baseId,
    this.createdAt,
    this.publishedAt,
  });

  final String id, programId, status, catalogVersion, scoringVersion;
  final String changeReason;
  final String? baseId, createdAt, publishedAt;
  final int revision, editVersion;
  final Map<String, dynamic> definition;
  bool get isDraft => status == 'draft';
  bool get isFas => programId == 'fas_periodic_assessment';

  factory AdminBuiltinAssessmentRevision.fromJson(Map<String, dynamic> row) =>
      AdminBuiltinAssessmentRevision(
        id: row['id'] as String,
        programId: row['program_id'] as String,
        revision: (row['revision'] as num).toInt(),
        status: row['status'] as String,
        definition: copyBuiltinDefinition(
          Map<String, dynamic>.from(row['definition'] as Map),
        ),
        catalogVersion: row['catalog_version'] as String,
        scoringVersion: row['scoring_version'] as String,
        editVersion: (row['edit_version'] as num).toInt(),
        changeReason: row['change_reason'] as String? ?? '',
        baseId: row['base_id'] as String?,
        createdAt: row['created_at'] as String?,
        publishedAt: row['published_at'] as String?,
      );
}

class AdminBuiltinAssessmentWorkspace {
  const AdminBuiltinAssessmentWorkspace({
    required this.revisions,
    this.currentRevisionId,
  });
  final List<AdminBuiltinAssessmentRevision> revisions;
  final String? currentRevisionId;
  factory AdminBuiltinAssessmentWorkspace.fromJson(Map<String, dynamic> row) =>
      AdminBuiltinAssessmentWorkspace(
        revisions: (row['revisions'] as List)
            .map(
              (item) => AdminBuiltinAssessmentRevision.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        currentRevisionId: row['current_revision_id'] as String?,
      );
}

class AdminBuiltinAssessmentReview {
  const AdminBuiltinAssessmentReview({
    required this.issues,
    required this.warnings,
    required this.changeCount,
    required this.existingGoalsPreserved,
  });
  final List<String> issues, warnings;
  final int changeCount, existingGoalsPreserved;
  factory AdminBuiltinAssessmentReview.fromJson(Map<String, dynamic> row) =>
      AdminBuiltinAssessmentReview(
        issues: (row['issues'] as List).cast<String>(),
        warnings: (row['warnings'] as List).cast<String>(),
        changeCount: (row['change_count'] as num).toInt(),
        existingGoalsPreserved: (row['existing_goals_preserved'] as num)
            .toInt(),
      );
}

abstract interface class AdminBuiltinAssessmentAuthoringRepository {
  Future<AdminBuiltinAssessmentWorkspace> workspace(String programId);
  Future<AdminBuiltinAssessmentRevision> createRevision({
    required String programId,
    required String baseId,
    required String requestId,
  });
  Future<AdminBuiltinAssessmentRevision> save({
    required AdminBuiltinAssessmentRevision revision,
    required Map<String, dynamic> definition,
    required String changeReason,
  });
  Future<AdminBuiltinAssessmentReview> review(String revisionId);
  Future<Map<String, dynamic>> preview({
    required String revisionId,
    required String category,
    required List<Map<String, dynamic>> marks,
    int? age,
    String? milestone,
  });
  Future<AdminBuiltinAssessmentRevision> publish(
    AdminBuiltinAssessmentRevision revision,
  );
  Future<AdminBuiltinAssessmentRevision> withdraw(
    AdminBuiltinAssessmentRevision revision,
  );
}

class SupabaseAdminBuiltinAssessmentAuthoringRepository
    implements AdminBuiltinAssessmentAuthoringRepository {
  const SupabaseAdminBuiltinAssessmentAuthoringRepository(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>> _call(
    String operation,
    Map<String, dynamic> parameters,
  ) async => Map<String, dynamic>.from(
    await client.rpc('admin_builtin_assessment_$operation', params: parameters)
        as Map,
  );

  @override
  Future<AdminBuiltinAssessmentWorkspace> workspace(String programId) async =>
      AdminBuiltinAssessmentWorkspace.fromJson(
        await _call('workspace', {'p_program_id': programId}),
      );

  @override
  Future<AdminBuiltinAssessmentRevision> createRevision({
    required String programId,
    required String baseId,
    required String requestId,
  }) async => AdminBuiltinAssessmentRevision.fromJson(
    await _call('create_revision', {
      'p_program_id': programId,
      'p_base_id': baseId,
      'p_request_id': requestId,
    }),
  );

  @override
  Future<AdminBuiltinAssessmentRevision> save({
    required AdminBuiltinAssessmentRevision revision,
    required Map<String, dynamic> definition,
    required String changeReason,
  }) async => AdminBuiltinAssessmentRevision.fromJson(
    await _call('save', {
      'p_revision_id': revision.id,
      'p_expected_edit_version': revision.editVersion,
      'p_definition': definition,
      'p_change_reason': changeReason,
    }),
  );

  @override
  Future<AdminBuiltinAssessmentReview> review(String revisionId) async =>
      AdminBuiltinAssessmentReview.fromJson(
        await _call('review', {'p_revision_id': revisionId}),
      );

  @override
  Future<Map<String, dynamic>> preview({
    required String revisionId,
    required String category,
    required List<Map<String, dynamic>> marks,
    int? age,
    String? milestone,
  }) => _call('preview', {
    'p_revision_id': revisionId,
    'p_category': category,
    'p_age': age,
    'p_milestone': milestone,
    'p_marks': marks,
  });

  Future<AdminBuiltinAssessmentRevision> _transition(
    String operation,
    AdminBuiltinAssessmentRevision revision,
  ) async => AdminBuiltinAssessmentRevision.fromJson(
    await _call(operation, {
      'p_revision_id': revision.id,
      'p_expected_edit_version': revision.editVersion,
    }),
  );

  @override
  Future<AdminBuiltinAssessmentRevision> publish(
    AdminBuiltinAssessmentRevision revision,
  ) => _transition('publish', revision);

  @override
  Future<AdminBuiltinAssessmentRevision> withdraw(
    AdminBuiltinAssessmentRevision revision,
  ) => _transition('withdraw', revision);
}
