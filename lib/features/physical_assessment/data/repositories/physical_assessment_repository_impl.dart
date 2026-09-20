import 'package:entrenaop/features/physical_assessment/data/datasources/physical_assessment_remote_datasource.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';

class PhysicalAssessmentRepositoryImpl implements PhysicalAssessmentRepository {
  const PhysicalAssessmentRepositoryImpl({required this.remoteDataSource});

  final PhysicalAssessmentRemoteDataSource remoteDataSource;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() {
    return remoteDataSource.getHistory();
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) {
    return remoteDataSource.saveAssessment(report, completedAt: completedAt);
  }
}
