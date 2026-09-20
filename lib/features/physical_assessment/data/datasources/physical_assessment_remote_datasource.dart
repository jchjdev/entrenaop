import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

abstract class PhysicalAssessmentRemoteDataSource {
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory();

  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  });
}
