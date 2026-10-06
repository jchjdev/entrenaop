import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

abstract class PhysicalAssessmentRepository {
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory();
  Future<List<PhysicalAssessmentHistoryEntry>> getHistoryForGoal(String goalId);

  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
    String? goalId,
  });
}
