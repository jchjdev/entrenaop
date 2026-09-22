import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:equatable/equatable.dart';

enum PreparationDetailStatus { initial, loading, ready, failure }

class PreparationDetailState extends Equatable {
  const PreparationDetailState({
    required this.weekStart,
    this.status = PreparationDetailStatus.initial,
    this.detail,
    this.publicTemplates = const [],
    this.personalTemplates = const [],
    this.busyTemplateId,
    this.errorMessage,
  });

  final PreparationDetailStatus status;
  final DateTime weekStart;
  final PreparationDetail? detail;
  final List<WorkoutTemplateSummary> publicTemplates;
  final List<WorkoutTemplateSummary> personalTemplates;
  final String? busyTemplateId;
  final String? errorMessage;

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  PreparationDetailState copyWith({
    PreparationDetailStatus? status,
    DateTime? weekStart,
    PreparationDetail? detail,
    List<WorkoutTemplateSummary>? publicTemplates,
    List<WorkoutTemplateSummary>? personalTemplates,
    String? busyTemplateId,
    bool clearBusy = false,
    String? errorMessage,
    bool clearError = false,
  }) => PreparationDetailState(
    status: status ?? this.status,
    weekStart: weekStart ?? this.weekStart,
    detail: detail ?? this.detail,
    publicTemplates: publicTemplates ?? this.publicTemplates,
    personalTemplates: personalTemplates ?? this.personalTemplates,
    busyTemplateId: clearBusy ? null : busyTemplateId ?? this.busyTemplateId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    weekStart,
    detail,
    publicTemplates,
    personalTemplates,
    busyTemplateId,
    errorMessage,
  ];
}
