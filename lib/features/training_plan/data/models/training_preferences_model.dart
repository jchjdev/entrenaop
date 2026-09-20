import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';

class TrainingPreferencesModel {
  const TrainingPreferencesModel._();

  static TrainingPreferences fromJson(Map<String, dynamic> json) {
    final targetDate = json['target_date'] as String?;
    return TrainingPreferences(
      availableDaysPerWeek: json['available_days_per_week'] as int,
      sessionDurationMinutes: json['session_duration_minutes'] as int,
      targetDate: targetDate == null ? null : DateTime.parse(targetDate),
      experience: _experienceFromDatabase(json['experience_level'] as String),
      equipment: (json['equipment'] as List<dynamic>)
          .cast<String>()
          .map(_equipmentFromDatabase)
          .toSet(),
      requiresProfessionalReview: json['requires_professional_review'] as bool,
    );
  }

  static Map<String, dynamic> toJson(
    TrainingPreferences preferences, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'available_days_per_week': preferences.availableDaysPerWeek,
      'session_duration_minutes': preferences.sessionDurationMinutes,
      'target_date': preferences.targetDate?.toIso8601String().split('T').first,
      'experience_level': preferences.experience.databaseValue,
      'equipment': preferences.equipment
          .map((item) => item.databaseValue)
          .toList(growable: false),
      'requires_professional_review': preferences.requiresProfessionalReview,
    };
  }
}

TrainingExperience _experienceFromDatabase(String value) => switch (value) {
  'starting' => TrainingExperience.starting,
  'occasional' => TrainingExperience.occasional,
  'consistent' => TrainingExperience.consistent,
  _ => throw FormatException('Nivel de experiencia desconocido: $value'),
};

TrainingEquipment _equipmentFromDatabase(String value) => switch (value) {
  'none' => TrainingEquipment.none,
  'pull_up_bar' => TrainingEquipment.pullUpBar,
  'free_weights' => TrainingEquipment.freeWeights,
  'gym' => TrainingEquipment.gym,
  'running_track' => TrainingEquipment.runningTrack,
  _ => throw FormatException('Material desconocido: $value'),
};

extension on TrainingExperience {
  String get databaseValue => switch (this) {
    TrainingExperience.starting => 'starting',
    TrainingExperience.occasional => 'occasional',
    TrainingExperience.consistent => 'consistent',
  };
}

extension on TrainingEquipment {
  String get databaseValue => switch (this) {
    TrainingEquipment.none => 'none',
    TrainingEquipment.pullUpBar => 'pull_up_bar',
    TrainingEquipment.freeWeights => 'free_weights',
    TrainingEquipment.gym => 'gym',
    TrainingEquipment.runningTrack => 'running_track',
  };
}
