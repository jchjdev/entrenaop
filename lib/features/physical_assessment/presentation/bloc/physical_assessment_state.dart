import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:equatable/equatable.dart';

enum PhysicalAssessmentStatus { editing, evaluated, saving, saved, failure }

class PhysicalAssessmentState extends Equatable {
  const PhysicalAssessmentState({
    this.category = AssessmentCategory.men,
    this.status = PhysicalAssessmentStatus.editing,
    this.report,
    this.savedAssessmentId,
    this.errorMessage,
  });

  final AssessmentCategory category;
  final PhysicalAssessmentStatus status;
  final AssessmentReport? report;
  final String? savedAssessmentId;
  final String? errorMessage;

  PhysicalAssessmentState copyWith({
    AssessmentCategory? category,
    PhysicalAssessmentStatus? status,
    AssessmentReport? report,
    bool clearReport = false,
    String? savedAssessmentId,
    bool clearSavedAssessment = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhysicalAssessmentState(
      category: category ?? this.category,
      status: status ?? this.status,
      report: clearReport ? null : report ?? this.report,
      savedAssessmentId: clearSavedAssessment
          ? null
          : savedAssessmentId ?? this.savedAssessmentId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    category,
    status,
    report,
    savedAssessmentId,
    errorMessage,
  ];
}
