import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

class AdminPerformanceSetup {
  const AdminPerformanceSetup(this.profiles, this.bindings);
  final List<StrengthExerciseDefinition> profiles;
  final List<Map<String, dynamic>> bindings;
}

class AdminProgram {
  const AdminProgram({
    required this.id,
    required this.name,
    required this.kind,
    required this.enabled,
  });

  final String id;
  final String name;
  final String kind;
  final bool enabled;

  factory AdminProgram.fromJson(Map<String, dynamic> json) => AdminProgram(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String,
    enabled: json['enabled'] as bool,
  );
}

class AdminProgramTest {
  const AdminProgramTest({
    this.id = '',
    required this.code,
    required this.name,
    required this.unit,
    required this.betterDirection,
    required this.protocolNotes,
    required this.definitionVersion,
    this.category = 'both',
    this.groupCode = '',
    this.displayOrder = 1,
    this.markStep = 1,
    this.minAge = 0,
    this.maxAge = 120,
    this.maxAttempts = 1,
    this.retryPolicy = 'none',
    this.distanceMeters,
    this.measurementProtocol,
  });

  final String id;
  final String code;
  final String name;
  final String unit;
  final String betterDirection;
  final String protocolNotes;
  final int definitionVersion;
  final String category;
  final String groupCode;
  final int displayOrder;
  final double markStep;
  final int minAge;
  final int maxAge;
  final int maxAttempts;
  final String retryPolicy;
  final int? distanceMeters;
  final String? measurementProtocol;

  factory AdminProgramTest.fromJson(Map<String, dynamic> json) =>
      AdminProgramTest(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        betterDirection: json['better_direction'] as String,
        protocolNotes: json['protocol_notes'] as String,
        definitionVersion: json['definition_version'] as int,
        category: json['category'] as String,
        groupCode: json['group_code'] as String,
        displayOrder: json['display_order'] as int,
        markStep: (json['mark_step'] as num).toDouble(),
        minAge: json['min_age'] as int? ?? 0,
        maxAge: json['max_age'] as int? ?? 120,
        maxAttempts: json['max_attempts'] as int? ?? 1,
        retryPolicy: json['retry_policy'] as String? ?? 'none',
        distanceMeters: json['distance_meters'] as int?,
        measurementProtocol: json['measurement_protocol'] as String?,
      );
}

class AdminProgramTrainingModule {
  const AdminProgramTrainingModule({
    required this.testId,
    required this.moduleKey,
  });

  final String testId;
  final String moduleKey;

  factory AdminProgramTrainingModule.fromJson(Map<String, dynamic> json) =>
      AdminProgramTrainingModule(
        testId: json['test_id'] as String,
        moduleKey: json['module_key'] as String,
      );
}

class AdminProgramScoringRule {
  const AdminProgramScoringRule({
    required this.version,
    required this.sourceUrl,
    required this.sourceLabel,
    required this.aggregation,
    required this.maxPoints,
    required this.minEachPoints,
    required this.minAggregatePoints,
    this.scoringMode = 'points',
    this.ageReference = 'assessment_date',
    this.ageReferenceOn,
    this.stageLabel = 'Ingreso',
    this.effectiveOn,
    this.expiresOn,
  });

  final String version;
  final String sourceUrl;
  final String sourceLabel;
  final String aggregation;
  final double maxPoints;
  final double minEachPoints;
  final double minAggregatePoints;
  final String scoringMode;
  final String ageReference;
  final String? ageReferenceOn;
  final String stageLabel;
  final String? effectiveOn;
  final String? expiresOn;

  factory AdminProgramScoringRule.fromJson(Map<String, dynamic> json) =>
      AdminProgramScoringRule(
        version: json['scoring_version'] as String,
        sourceUrl: json['source_url'] as String,
        sourceLabel: json['source_label'] as String,
        aggregation: json['aggregation'] as String,
        maxPoints: (json['max_points'] as num).toDouble(),
        minEachPoints: (json['min_each_points'] as num).toDouble(),
        minAggregatePoints: (json['min_aggregate_points'] as num).toDouble(),
        scoringMode: json['scoring_mode'] as String? ?? 'points',
        ageReference: json['age_reference'] as String? ?? 'assessment_date',
        ageReferenceOn: json['age_reference_on'] as String?,
        stageLabel: json['stage_label'] as String? ?? 'Ingreso',
        effectiveOn: json['effective_on'] as String?,
        expiresOn: json['expires_on'] as String?,
      );
}

class AdminScoreBand {
  const AdminScoreBand({
    this.id = '',
    required this.category,
    this.minMark,
    this.maxMark,
    required this.points,
    this.minAge = 0,
    this.maxAge = 120,
  });

  final String id;
  final String category;
  final double? minMark;
  final double? maxMark;
  final double points;
  final int minAge;
  final int maxAge;

  factory AdminScoreBand.fromJson(Map<String, dynamic> json) => AdminScoreBand(
    id: json['id'] as String,
    category: json['category'] as String,
    minMark: (json['min_mark'] as num?)?.toDouble(),
    maxMark: (json['max_mark'] as num?)?.toDouble(),
    points: (json['points'] as num).toDouble(),
    minAge: json['min_age'] as int? ?? 0,
    maxAge: json['max_age'] as int? ?? 120,
  );
}

class AdminPassStandard {
  const AdminPassStandard({
    this.id = '',
    required this.category,
    required this.minAge,
    required this.maxAge,
    required this.threshold,
  });

  final String id;
  final String category;
  final int minAge;
  final int maxAge;
  final double threshold;

  factory AdminPassStandard.fromJson(Map<String, dynamic> json) =>
      AdminPassStandard(
        id: json['id'] as String,
        category: json['category'] as String,
        minAge: json['min_age'] as int,
        maxAge: json['max_age'] as int,
        threshold: (json['threshold'] as num).toDouble(),
      );
}

class AdminContextualResult {
  const AdminContextualResult({
    required this.passed,
    required this.age,
    required this.mode,
    required this.total,
    required this.details,
  });
  final bool passed;
  final int age;
  final String mode;
  final double? total;
  final List<AdminContextualDetail> details;

  factory AdminContextualResult.fromJson(Map<String, dynamic> json) =>
      AdminContextualResult(
        passed: json['passed'] as bool,
        age: json['age'] as int,
        mode: json['scoring_mode'] as String,
        total: (json['total'] as num?)?.toDouble(),
        details: [
          for (final row in json['details'] as List<dynamic>)
            AdminContextualDetail.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
        ],
      );
}

class AdminContextualDetail {
  const AdminContextualDetail({
    required this.name,
    required this.passed,
    required this.mark,
    this.points,
    this.minimumMark,
    this.margin,
  });
  final String name;
  final bool passed;
  final double? mark;
  final double? points;
  final double? minimumMark;
  final double? margin;

  factory AdminContextualDetail.fromJson(Map<String, dynamic> json) =>
      AdminContextualDetail(
        name: json['name'] as String,
        passed: json['passed'] as bool,
        mark: (json['mark'] as num?)?.toDouble(),
        points: (json['points'] as num?)?.toDouble(),
        minimumMark: (json['minimum_mark'] as num?)?.toDouble(),
        margin: (json['margin'] as num?)?.toDouble(),
      );
}

class AdminAttemptMark {
  const AdminAttemptMark({required this.testId, this.mark, this.attempts});

  final String testId;
  final double? mark;
  final List<AdminExerciseAttempt>? attempts;

  Map<String, dynamic> toJson() => {
    'test_id': testId,
    if (attempts == null) 'mark': mark,
    if (attempts != null)
      'attempts': [for (final attempt in attempts!) attempt.toJson()],
  };
}

class AdminExerciseAttempt {
  const AdminExerciseAttempt({required this.valid, this.mark});
  final bool valid;
  final double? mark;
  Map<String, dynamic> toJson() => {'valid': valid, if (valid) 'mark': mark};
}

class AdminAttemptPreview {
  const AdminAttemptPreview({
    required this.total,
    required this.passed,
    required this.eachPassed,
    required this.version,
    required this.details,
  });

  final double total;
  final bool passed;
  final bool eachPassed;
  final String version;
  final List<AdminAttemptDetail> details;

  factory AdminAttemptPreview.fromJson(Map<String, dynamic> json) =>
      AdminAttemptPreview(
        total: (json['total'] as num).toDouble(),
        passed: json['passed'] as bool,
        eachPassed: json['each_passed'] as bool,
        version: json['scoring_version'] as String,
        details: [
          for (final row in json['details'] as List<dynamic>)
            AdminAttemptDetail.fromJson(Map<String, dynamic>.from(row as Map)),
        ],
      );
}

class AdminAttemptDetail {
  const AdminAttemptDetail({
    required this.testId,
    required this.mark,
    required this.points,
  });

  final String testId;
  final double mark;
  final double points;

  factory AdminAttemptDetail.fromJson(Map<String, dynamic> json) =>
      AdminAttemptDetail(
        testId: json['test_id'] as String,
        mark: (json['mark'] as num).toDouble(),
        points: (json['points'] as num).toDouble(),
      );
}

abstract class AdminProgramRepository {
  Future<AdminPerformanceSetup> loadPerformanceSetup(String programId);
  Future<void> savePerformanceStrategy(
    String testId,
    Map<String, dynamic>? strategy,
  );
  Future<bool> hasAccess();
  Future<List<AdminProgram>> listPrograms();
  Future<void> createDraft({required String name, required String kind});
  Future<List<String>> assessmentIssues(String programId);
  Future<void> publishAssessment(String programId);
  Future<void> cloneAssessmentVersion(
    String programId,
    String name,
    String version,
  );
  Future<List<AdminProgramTest>> listTests(String programId);
  Future<void> createTest(String programId, AdminProgramTest test);
  Future<void> updateTest(AdminProgramTest test, {bool resetBands = false});
  Future<void> deleteTest(String testId);
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String programId,
  );
  Future<void> setRunningTwoKilometreModule(
    String testId, {
    required bool enabled,
  });
  Future<AdminProgramScoringRule?> getScoringRule(String programId);
  Future<void> saveScoringRule(String programId, AdminProgramScoringRule rule);
  Future<List<AdminScoreBand>> listScoreBands(String testId);
  Future<void> addScoreBand(String testId, AdminScoreBand band);
  Future<void> updateScoreBand(String testId, AdminScoreBand band);
  Future<void> deleteScoreBand(String bandId);
  Future<void> importScoreBands(
    String testId,
    List<AdminScoreBand> bands, {
    required bool replace,
  });
  Future<List<AdminPassStandard>> listPassStandards(String testId);
  Future<void> savePassStandard(String testId, AdminPassStandard standard);
  Future<void> deletePassStandard(String standardId);
  Future<AdminContextualResult> previewContextualAttempt(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AdminAttemptMark> marks,
  );
  Future<AdminAttemptPreview> previewAttempt(
    String programId,
    String category,
    List<AdminAttemptMark> marks,
  );
}

class SupabaseAdminProgramRepository implements AdminProgramRepository {
  SupabaseAdminProgramRepository(this._client);

  final SupabaseClient _client;
  @override
  Future<AdminPerformanceSetup> loadPerformanceSetup(String programId) async {
    final profiles = await _client
        .from('exercise_training_profiles')
        .select('definition_version,definition');
    final bindings = await _client
        .from('program_test_training_bindings')
        .select()
        .eq('program_id', programId);
    return AdminPerformanceSetup(
      profiles
          .map(
            (p) => StrengthExerciseCatalogCodec.decodeDefinition(
              Map<String, dynamic>.from(p['definition'] as Map),
              definitionVersion: p['definition_version'] as int,
            ),
          )
          .toList(),
      bindings.map((r) => Map<String, dynamic>.from(r)).toList(),
    );
  }

  @override
  Future<void> savePerformanceStrategy(
    String testId,
    Map<String, dynamic>? strategy,
  ) async {
    await _client.rpc(
      'set_admin_performance_strategy',
      params: {
        'p_test_id': testId,
        'p_code': strategy?['profile_code'],
        'p_version': strategy?['profile_version'],
        'p_measurement': strategy?['measurement_mode'],
        'p_review_note': strategy?['review_note'] ?? '',
        'p_parameters': strategy?['training_parameters'] ?? <String, dynamic>{},
      },
    );
  }

  @override
  Future<bool> hasAccess() async =>
      await _client.rpc('is_admin') as bool? ?? false;

  @override
  Future<List<AdminProgram>> listPrograms() async {
    final rows = await _client
        .from('preparation_programs')
        .select('id,name,kind,enabled')
        .order('name');
    return rows.map(AdminProgram.fromJson).toList();
  }

  @override
  Future<void> createDraft({required String name, required String kind}) async {
    await _client.rpc(
      'create_admin_preparation_program',
      params: {'p_name': name, 'p_kind': kind},
    );
  }

  @override
  Future<List<String>> assessmentIssues(String programId) async {
    final result = await _client.rpc(
      'admin_program_assessment_issues_v3',
      params: {'p_program_id': programId},
    );
    return [for (final item in result as List<dynamic>) item as String];
  }

  @override
  Future<void> publishAssessment(String programId) async {
    await _client.rpc(
      'publish_admin_program_assessment',
      params: {'p_program_id': programId},
    );
  }

  @override
  Future<void> cloneAssessmentVersion(
    String programId,
    String name,
    String version,
  ) async {
    await _client.rpc(
      'clone_admin_program_assessment_version_v2',
      params: {
        'p_source_program_id': programId,
        'p_name': name,
        'p_scoring_version': version,
      },
    );
  }

  @override
  Future<List<AdminProgramTest>> listTests(String programId) async {
    final rows = await _client
        .from('program_assessment_tests')
        .select(
          'id,code,name,unit,better_direction,protocol_notes,definition_version,category,group_code,display_order,mark_step,min_age,max_age,max_attempts,retry_policy,distance_meters,measurement_protocol',
        )
        .eq('program_id', programId)
        .order('display_order')
        .order('category');
    return rows.map(AdminProgramTest.fromJson).toList();
  }

  @override
  Future<void> createTest(String programId, AdminProgramTest test) async {
    await _client.rpc(
      'create_admin_program_assessment_test_v5',
      params: {
        'p_program_id': programId,
        'p_code': test.code,
        'p_name': test.name,
        'p_unit': test.unit,
        'p_better_direction': test.betterDirection,
        'p_protocol_notes': test.protocolNotes,
        'p_category': test.category,
        'p_group_code': test.groupCode,
        'p_display_order': test.displayOrder,
        'p_mark_step': test.markStep,
        'p_min_age': test.minAge,
        'p_max_age': test.maxAge,
        'p_max_attempts': test.maxAttempts,
        'p_retry_policy': test.retryPolicy,
        'p_distance_meters': test.distanceMeters,
        'p_measurement_protocol': test.measurementProtocol,
      },
    );
  }

  @override
  Future<void> updateTest(
    AdminProgramTest test, {
    bool resetBands = false,
  }) async {
    await _client.rpc(
      'update_admin_program_assessment_test_v5',
      params: {
        'p_test_id': test.id,
        'p_name': test.name,
        'p_unit': test.unit,
        'p_better_direction': test.betterDirection,
        'p_protocol_notes': test.protocolNotes,
        'p_category': test.category,
        'p_display_order': test.displayOrder,
        'p_mark_step': test.markStep,
        'p_min_age': test.minAge,
        'p_max_age': test.maxAge,
        'p_max_attempts': test.maxAttempts,
        'p_retry_policy': test.retryPolicy,
        'p_distance_meters': test.distanceMeters,
        'p_measurement_protocol': test.measurementProtocol,
        'p_reset_bands': resetBands,
      },
    );
  }

  @override
  Future<void> deleteTest(String testId) async {
    await _client.rpc(
      'delete_admin_program_assessment_test',
      params: {'p_test_id': testId},
    );
  }

  @override
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String programId,
  ) async {
    final rows = await _client
        .from('program_training_modules')
        .select('test_id,module_key')
        .eq('program_id', programId);
    return rows.map(AdminProgramTrainingModule.fromJson).toList();
  }

  @override
  Future<void> setRunningTwoKilometreModule(
    String testId, {
    required bool enabled,
  }) async {
    await _client.rpc(
      'set_admin_program_training_module',
      params: {
        'p_test_id': testId,
        'p_module_key': enabled ? 'running_2000m_v1' : null,
      },
    );
  }

  @override
  Future<AdminProgramScoringRule?> getScoringRule(String programId) async {
    final row = await _client
        .from('program_assessment_scoring_rules')
        .select(
          'scoring_version,source_url,source_label,aggregation,max_points,min_each_points,min_aggregate_points,scoring_mode,age_reference,age_reference_on,stage_label,effective_on,expires_on',
        )
        .eq('program_id', programId)
        .maybeSingle();
    return row == null ? null : AdminProgramScoringRule.fromJson(row);
  }

  @override
  Future<void> saveScoringRule(
    String programId,
    AdminProgramScoringRule rule,
  ) async {
    await _client.rpc(
      'save_admin_program_scoring_rule_v3',
      params: {
        'p_program_id': programId,
        'p_scoring_version': rule.version,
        'p_source_url': rule.sourceUrl,
        'p_source_label': rule.sourceLabel,
        'p_aggregation': rule.aggregation,
        'p_max_points': rule.maxPoints,
        'p_min_each_points': rule.minEachPoints,
        'p_min_aggregate_points': rule.minAggregatePoints,
        'p_scoring_mode': rule.scoringMode,
        'p_age_reference': rule.ageReference,
        'p_age_reference_on': rule.ageReferenceOn,
        'p_stage_label': rule.stageLabel,
        'p_effective_on': rule.effectiveOn,
        'p_expires_on': rule.expiresOn,
      },
    );
  }

  @override
  Future<List<AdminScoreBand>> listScoreBands(String testId) async {
    final rows = await _client
        .from('program_assessment_score_bands')
        .select('id,category,min_mark,max_mark,points,min_age,max_age')
        .eq('test_id', testId)
        .order('category')
        .order('points');
    return rows.map(AdminScoreBand.fromJson).toList();
  }

  @override
  Future<void> addScoreBand(String testId, AdminScoreBand band) async {
    await _client.rpc(
      'save_admin_program_score_band_v2',
      params: {
        'p_test_id': testId,
        'p_category': band.category,
        'p_min_mark': band.minMark,
        'p_max_mark': band.maxMark,
        'p_points': band.points,
        'p_band_id': null,
        'p_min_age': band.minAge,
        'p_max_age': band.maxAge,
      },
    );
  }

  @override
  Future<void> updateScoreBand(String testId, AdminScoreBand band) async {
    await _client.rpc(
      'save_admin_program_score_band_v2',
      params: {
        'p_test_id': testId,
        'p_band_id': band.id,
        'p_category': band.category,
        'p_min_mark': band.minMark,
        'p_max_mark': band.maxMark,
        'p_points': band.points,
        'p_min_age': band.minAge,
        'p_max_age': band.maxAge,
      },
    );
  }

  @override
  Future<void> deleteScoreBand(String bandId) async {
    await _client.rpc(
      'delete_admin_program_score_band',
      params: {'p_band_id': bandId},
    );
  }

  @override
  Future<void> importScoreBands(
    String testId,
    List<AdminScoreBand> bands, {
    required bool replace,
  }) async {
    await _client.rpc(
      'import_admin_program_score_bands',
      params: {
        'p_test_id': testId,
        'p_replace': replace,
        'p_rows': [
          for (final band in bands)
            {
              'category': band.category,
              'min_age': band.minAge,
              'max_age': band.maxAge,
              'min_mark': band.minMark,
              'max_mark': band.maxMark,
              'points': band.points,
            },
        ],
      },
    );
  }

  @override
  Future<List<AdminPassStandard>> listPassStandards(String testId) async {
    final rows = await _client
        .from('program_assessment_pass_standards')
        .select('id,category,min_age,max_age,threshold')
        .eq('test_id', testId)
        .order('category')
        .order('min_age');
    return rows.map(AdminPassStandard.fromJson).toList();
  }

  @override
  Future<void> savePassStandard(
    String testId,
    AdminPassStandard standard,
  ) async {
    await _client.rpc(
      'save_admin_program_pass_standard',
      params: {
        'p_test_id': testId,
        'p_standard_id': standard.id.isEmpty ? null : standard.id,
        'p_category': standard.category,
        'p_min_age': standard.minAge,
        'p_max_age': standard.maxAge,
        'p_threshold': standard.threshold,
      },
    );
  }

  @override
  Future<void> deletePassStandard(String standardId) async {
    await _client.rpc(
      'delete_admin_program_pass_standard',
      params: {'p_standard_id': standardId},
    );
  }

  @override
  Future<AdminContextualResult> previewContextualAttempt(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AdminAttemptMark> marks,
  ) async {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final result = await _client.rpc(
      'preview_program_assessment_attempt_v3',
      params: {
        'p_program_id': programId,
        'p_category': category,
        'p_birth_date': date(birthDate),
        'p_assessed_on': date(assessedOn),
        'p_reference_on': referenceOn == null ? null : date(referenceOn),
        'p_marks': [for (final mark in marks) mark.toJson()],
      },
    );
    return AdminContextualResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<AdminAttemptPreview> previewAttempt(
    String programId,
    String category,
    List<AdminAttemptMark> marks,
  ) async {
    final result = await _client.rpc(
      'preview_program_assessment_attempt',
      params: {
        'p_program_id': programId,
        'p_category': category,
        'p_marks': [
          for (final mark in marks) {'test_id': mark.testId, 'mark': mark.mark},
        ],
      },
    );
    return AdminAttemptPreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
