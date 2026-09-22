import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:equatable/equatable.dart';

enum PreparationDetailStatus { initial, loading, ready, failure }

class PreparationDetailState extends Equatable {
  const PreparationDetailState({
    required this.weekStart,
    this.status = PreparationDetailStatus.initial,
    this.detail,
    this.errorMessage,
  });

  final PreparationDetailStatus status;
  final DateTime weekStart;
  final PreparationDetail? detail;
  final String? errorMessage;

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  PreparationDetailState copyWith({
    PreparationDetailStatus? status,
    DateTime? weekStart,
    PreparationDetail? detail,
    String? errorMessage,
    bool clearError = false,
  }) => PreparationDetailState(
    status: status ?? this.status,
    weekStart: weekStart ?? this.weekStart,
    detail: detail ?? this.detail,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [status, weekStart, detail, errorMessage];
}
