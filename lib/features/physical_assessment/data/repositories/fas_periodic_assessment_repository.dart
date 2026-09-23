import 'package:supabase_flutter/supabase_flutter.dart';

class FasPeriodicAssessmentEntry {
  const FasPeriodicAssessmentEntry({
    required this.id,
    required this.completedAt,
    required this.category,
    required this.age,
    required this.isPreEffectiveReference,
    required this.marks,
  });

  final String id;
  final DateTime completedAt;
  final String category;
  final int age;
  final bool isPreEffectiveReference;
  final List<FasPeriodicAssessmentMark> marks;

  bool get meetsAllMinimums => marks.every((mark) => mark.meetsMinimum);
}

class FasPeriodicAssessmentMark {
  const FasPeriodicAssessmentMark({
    required this.testId,
    required this.testName,
    required this.unit,
    required this.value,
    required this.threshold,
    required this.meetsMinimum,
  });

  final String testId;
  final String testName;
  final String unit;
  final int value;
  final int threshold;
  final bool meetsMinimum;
}

class FasPeriodicAssessmentRepository {
  const FasPeriodicAssessmentRepository(this._client);

  final SupabaseClient _client;

  Future<List<FasPeriodicAssessmentEntry>> history(String goalId) async {
    final response = await _client
        .from('fas_periodic_results')
        .select()
        .eq('preparation_goal_id', goalId)
        .order('completed_at', ascending: false);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in response) {
      final id = row['assessment_id'] as String;
      grouped.putIfAbsent(id, () => []).add(row);
    }
    return grouped.entries.map((item) {
      final header = item.value.first;
      final marks =
          item.value
              .map(
                (row) => FasPeriodicAssessmentMark(
                  testId: row['test_id'] as String,
                  testName: row['test_name'] as String,
                  unit: row['unit'] as String,
                  value: (row['value'] as num).toInt(),
                  threshold: (row['threshold'] as num).toInt(),
                  meetsMinimum: row['meets_minimum'] as bool,
                ),
              )
              .toList()
            ..sort(
              (a, b) => _testOrder(a.testId).compareTo(_testOrder(b.testId)),
            );
      return FasPeriodicAssessmentEntry(
        id: item.key,
        completedAt: DateTime.parse(header['completed_at'] as String).toLocal(),
        category: header['category'] as String,
        age: (header['age_at_assessment'] as num).toInt(),
        isPreEffectiveReference: header['is_pre_effective_reference'] as bool,
        marks: marks,
      );
    }).toList()..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  Future<String> save({
    required String goalId,
    required String category,
    required int age,
    required Map<String, int> marks,
  }) async {
    final id = await _client.rpc(
      'record_fas_periodic_assessment',
      params: {
        'p_preparation_goal_id': goalId,
        'p_category': category,
        'p_age': age,
        'p_marks': marks.entries
            .map((mark) => {'test_id': mark.key, 'value': mark.value})
            .toList(growable: false),
      },
    );
    if (id is! String || id.isEmpty) {
      throw const FormatException('No se pudo guardar la evaluación.');
    }
    return id;
  }
}

int _testOrder(String id) => switch (id) {
  'upper_body_push_ups_2_min' => 0,
  'abdominal_plank' => 1,
  'run_2000_m' => 2,
  'agility_speed_circuit' => 3,
  _ => 4,
};
