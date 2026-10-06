import 'package:equatable/equatable.dart';

/// Estado decidido por el servidor; consultar la agenda no elige una política.
class AdaptiveProgramProgress extends Equatable {
  const AdaptiveProgramProgress({
    required this.goalId,
    required this.name,
    required this.status,
    required this.message,
    this.currentWeek,
    this.nextGenerationOn,
  });

  final String goalId;
  final String name;
  final String status;
  final String message;
  final DateTime? currentWeek;
  final DateTime? nextGenerationOn;
  bool get isStarted => status != 'draft';
  bool get needsReview => status == 'needs_review';
  bool get isPaused => status == 'paused';
  bool get isCurrent => status == 'training' || needsReview;

  @override
  List<Object?> get props => [
    goalId,
    name,
    status,
    message,
    currentWeek,
    nextGenerationOn,
  ];
}
