import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';

class SavePhysicalAssessmentUseCase {
  const SavePhysicalAssessmentUseCase(this._repository);

  final PhysicalAssessmentRepository _repository;

  Future<String> call(
    AssessmentReport report, {
    DateTime? completedAt,
    String? goalId,
  }) {
    return _repository.saveAssessment(
      report,
      completedAt: completedAt,
      goalId: goalId,
    );
  }
}
