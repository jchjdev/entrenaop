import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramAssessmentRule {
  const ProgramAssessmentRule({
    required this.mode,
    required this.version,
    required this.stage,
    required this.ageReference,
    this.referenceOn,
  });
  final String mode;
  final String version;
  final String stage;
  final String ageReference;
  final DateTime? referenceOn;

  factory ProgramAssessmentRule.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentRule(
        mode: json['scoring_mode'] as String,
        version: json['scoring_version'] as String,
        stage: json['stage_label'] as String,
        ageReference: json['age_reference'] as String,
        referenceOn: json['age_reference_on'] == null
            ? null
            : DateTime.parse(json['age_reference_on'] as String),
      );
}

class ProgramAssessmentTest {
  const ProgramAssessmentTest({
    required this.id,
    required this.name,
    required this.unit,
    required this.markStep,
    required this.order,
    required this.protocol,
    this.maxAttempts = 1,
    this.retryPolicy = 'none',
  });
  final String id;
  final String name;
  final String unit;
  final double markStep;
  final int order;
  final String protocol;
  final int maxAttempts;
  final String retryPolicy;

  factory ProgramAssessmentTest.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentTest(
        id: json['test_id'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String,
        markStep: (json['mark_step'] as num).toDouble(),
        order: json['display_order'] as int,
        protocol: json['protocol_notes'] as String,
        maxAttempts: json['max_attempts'] as int? ?? 1,
        retryPolicy: json['retry_policy'] as String? ?? 'none',
      );
}

class ProgramAssessmentContext {
  const ProgramAssessmentContext({required this.age, required this.tests});
  final int age;
  final List<ProgramAssessmentTest> tests;

  factory ProgramAssessmentContext.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentContext(
        age: json['age'] as int,
        tests: [
          for (final row in json['tests'] as List<dynamic>)
            ProgramAssessmentTest.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
        ],
      );
}

class ProgramAssessmentResult {
  const ProgramAssessmentResult({
    required this.passed,
    required this.age,
    required this.version,
    required this.details,
    this.total,
  });
  final bool passed;
  final int age;
  final String version;
  final double? total;
  final List<ProgramAssessmentDetail> details;

  factory ProgramAssessmentResult.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentResult(
        passed: json['passed'] as bool,
        age: json['age'] as int,
        version: json['scoring_version'] as String,
        total: (json['total'] as num?)?.toDouble(),
        details: [
          for (final row in json['details'] as List<dynamic>)
            ProgramAssessmentDetail.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
        ],
      );
}

class ProgramAssessmentDetail {
  const ProgramAssessmentDetail({
    this.testId = '',
    required this.name,
    required this.passed,
    required this.mark,
    this.points,
    this.minimumMark,
    this.margin,
  });
  final String testId;
  final String name;
  final bool passed;
  final double? mark;
  final double? points;
  final double? minimumMark;
  final double? margin;

  factory ProgramAssessmentDetail.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentDetail(
        testId: json['test_id'] as String? ?? '',
        name: json['name'] as String,
        passed: json['passed'] as bool,
        mark: (json['mark'] as num?)?.toDouble(),
        points: (json['points'] as num?)?.toDouble(),
        minimumMark: (json['minimum_mark'] as num?)?.toDouble(),
        margin: (json['margin'] as num?)?.toDouble(),
      );
}

class ProgramAssessmentAttempt {
  const ProgramAssessmentAttempt({
    required this.id,
    required this.assessedOn,
    required this.category,
    required this.result,
    this.marks = const [],
  });
  final String id;
  final DateTime assessedOn;
  final String category;
  final ProgramAssessmentResult result;
  final List<AssessmentMarkInput> marks;

  factory ProgramAssessmentAttempt.fromJson(Map<String, dynamic> json) =>
      ProgramAssessmentAttempt(
        id: json['id'] as String,
        assessedOn: DateTime.parse(json['assessed_on'] as String),
        category: json['category'] as String,
        result: ProgramAssessmentResult.fromJson(
          Map<String, dynamic>.from(json['result'] as Map),
        ),
        marks: [
          for (final entry in json['marks'] as List<dynamic>? ?? const [])
            AssessmentMarkInput.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
        ],
      );
}

class AssessmentMarkInput {
  const AssessmentMarkInput({required this.testId, required this.attempts});
  final String testId;
  final List<AssessmentExerciseAttempt> attempts;
  factory AssessmentMarkInput.fromJson(Map<String, dynamic> json) =>
      AssessmentMarkInput(
        testId: json['test_id'] as String,
        attempts: json['attempts'] is List
            ? [
                for (final item in json['attempts'] as List<dynamic>)
                  AssessmentExerciseAttempt.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
              ]
            : [
                AssessmentExerciseAttempt(
                  valid: true,
                  mark: (json['mark'] as num?)?.toDouble(),
                ),
              ],
      );
  Map<String, dynamic> toJson() => {
    'test_id': testId,
    'attempts': [for (final attempt in attempts) attempt.toJson()],
  };
}

class AssessmentExerciseAttempt {
  const AssessmentExerciseAttempt({required this.valid, this.mark});
  final bool valid;
  final double? mark;
  factory AssessmentExerciseAttempt.fromJson(Map<String, dynamic> json) =>
      AssessmentExerciseAttempt(
        valid: json['valid'] as bool,
        mark: (json['mark'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toJson() => {'valid': valid, if (valid) 'mark': mark};
}

abstract class ProgramAssessmentRepository {
  Future<ProgramAssessmentRule> rule(String programId);
  Future<ProgramAssessmentContext> contextFor(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
  );
  Future<ProgramAssessmentResult> preview(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AssessmentMarkInput> marks,
  );
  Future<void> save(
    String goalId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    List<AssessmentMarkInput> marks,
  );
  Future<List<ProgramAssessmentAttempt>> history(String goalId);
}

class SupabaseProgramAssessmentRepository
    implements ProgramAssessmentRepository {
  const SupabaseProgramAssessmentRepository(this._client);
  final SupabaseClient _client;

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Future<ProgramAssessmentRule> rule(String programId) async {
    final row = await _client
        .from('program_assessment_scoring_rules')
        .select(
          'scoring_mode,scoring_version,stage_label,age_reference,age_reference_on',
        )
        .eq('program_id', programId)
        .single();
    return ProgramAssessmentRule.fromJson(row);
  }

  @override
  Future<ProgramAssessmentContext> contextFor(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
  ) async {
    final result = await _client.rpc(
      'resolve_program_assessment_tests_v3',
      params: {
        'p_program_id': programId,
        'p_category': category,
        'p_birth_date': _date(birthDate),
        'p_assessed_on': _date(assessedOn),
        'p_reference_on': referenceOn == null ? null : _date(referenceOn),
      },
    );
    return ProgramAssessmentContext.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<ProgramAssessmentResult> preview(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AssessmentMarkInput> marks,
  ) async {
    final result = await _client.rpc(
      'preview_program_assessment_attempt_v3',
      params: {
        'p_program_id': programId,
        'p_category': category,
        'p_birth_date': _date(birthDate),
        'p_assessed_on': _date(assessedOn),
        'p_reference_on': referenceOn == null ? null : _date(referenceOn),
        'p_marks': [for (final mark in marks) mark.toJson()],
      },
    );
    return ProgramAssessmentResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<void> save(
    String goalId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    List<AssessmentMarkInput> marks,
  ) async {
    await _client.rpc(
      'save_program_assessment_attempt',
      params: {
        'p_goal_id': goalId,
        'p_category': category,
        'p_birth_date': _date(birthDate),
        'p_assessed_on': _date(assessedOn),
        'p_marks': [for (final mark in marks) mark.toJson()],
      },
    );
  }

  @override
  Future<List<ProgramAssessmentAttempt>> history(String goalId) async {
    final rows = await _client
        .from('program_assessment_attempts')
        .select('id,assessed_on,category,marks,result')
        .eq('preparation_goal_id', goalId)
        .order('assessed_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(ProgramAssessmentAttempt.fromJson).toList();
  }
}
