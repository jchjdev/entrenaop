import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';

class GetPhysicalAssessmentHistoryUseCase {
  const GetPhysicalAssessmentHistoryUseCase(this._repository);

  final PhysicalAssessmentRepository _repository;

  Future<List<PhysicalAssessmentHistoryEntry>> call() {
    return _repository.getHistory();
  }
}
