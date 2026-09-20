import 'package:equatable/equatable.dart';

enum TrainingExperience { starting, occasional, consistent }

enum TrainingEquipment { none, pullUpBar, freeWeights, gym, runningTrack }

class TrainingPreferences extends Equatable {
  const TrainingPreferences({
    required this.availableDaysPerWeek,
    required this.sessionDurationMinutes,
    required this.experience,
    required this.equipment,
    required this.requiresProfessionalReview,
    this.targetDate,
  });

  final int availableDaysPerWeek;
  final int sessionDurationMinutes;
  final DateTime? targetDate;
  final TrainingExperience experience;
  final Set<TrainingEquipment> equipment;
  final bool requiresProfessionalReview;

  @override
  List<Object?> get props => [
    availableDaysPerWeek,
    sessionDurationMinutes,
    targetDate,
    experience,
    equipment,
    requiresProfessionalReview,
  ];
}
