import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

abstract class PhysicalAssessmentRepository {
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  });
}
