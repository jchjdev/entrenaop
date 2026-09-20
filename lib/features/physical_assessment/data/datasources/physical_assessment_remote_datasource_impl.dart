import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/features/physical_assessment/data/datasources/physical_assessment_remote_datasource.dart';
import 'package:entrenaop/features/physical_assessment/data/models/physical_assessment_history_model.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhysicalAssessmentRemoteDataSourceImpl
    implements PhysicalAssessmentRemoteDataSource {
  const PhysicalAssessmentRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async {
    try {
      final response = await supabaseClient
          .from('physical_assessment_results')
          .select()
          .order('completed_at', ascending: false)
          .order('test_id');

      return PhysicalAssessmentHistoryModel.fromRows(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (error) {
      throw ServerException(error.toString());
    }
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) async {
    try {
      // Flutter envía únicamente hechos medidos. La RPC vuelve a validar en
      // PostgreSQL el catálogo, el hito y el conjunto exacto de pruebas.
      final response = await supabaseClient.rpc(
        'record_physical_assessment',
        params: {
          'p_catalog_version': report.catalogVersion,
          'p_category': report.category.databaseValue,
          'p_milestone': report.milestone.databaseValue,
          'p_marks': report.results
              .map(
                (result) => {
                  'test_id': result.mark.testId,
                  'value': result.mark.value,
                },
              )
              .toList(growable: false),
          'p_completed_at': (completedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
        },
      );

      if (response is! String || response.isEmpty) {
        throw const FormatException('Supabase no devolvió el identificador.');
      }
      return response;
    } catch (error) {
      throw ServerException(error.toString());
    }
  }
}

extension on AssessmentCategory {
  String get databaseValue => switch (this) {
    AssessmentCategory.men => 'men',
    AssessmentCategory.women => 'women',
  };
}

extension on AssessmentMilestone {
  String get databaseValue => switch (this) {
    AssessmentMilestone.entry => 'entry',
    AssessmentMilestone.endOfGeneralMilitaryTraining =>
      'end_of_general_military_training',
    AssessmentMilestone.endOfTraining => 'end_of_training',
  };
}
