import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:equatable/equatable.dart';

enum PhysicalAssessmentStatus { editing, evaluated }

class PhysicalAssessmentState extends Equatable {
  const PhysicalAssessmentState({
    this.category = AssessmentCategory.men,
    this.status = PhysicalAssessmentStatus.editing,
    this.report,
  });

  final AssessmentCategory category;
  final PhysicalAssessmentStatus status;
  final AssessmentReport? report;

  PhysicalAssessmentState copyWith({
    AssessmentCategory? category,
    PhysicalAssessmentStatus? status,
    AssessmentReport? report,
    bool clearReport = false,
  }) {
    return PhysicalAssessmentState(
      category: category ?? this.category,
      status: status ?? this.status,
      report: clearReport ? null : report ?? this.report,
    );
  }

  @override
  List<Object?> get props => [category, status, report];
}
