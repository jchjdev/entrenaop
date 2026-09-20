import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:equatable/equatable.dart';

enum PhysicalAssessmentHistoryStatus { initial, loading, loaded, failure }

class PhysicalAssessmentHistoryState extends Equatable {
  const PhysicalAssessmentHistoryState({
    this.status = PhysicalAssessmentHistoryStatus.initial,
    this.entries = const [],
    this.progress = const [],
    this.errorMessage,
  });

  final PhysicalAssessmentHistoryStatus status;
  final List<PhysicalAssessmentHistoryEntry> entries;
  final List<AssessmentProgress> progress;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, entries, progress, errorMessage];
}
