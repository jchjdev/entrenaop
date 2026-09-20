import 'package:entrenaop/features/training_plan/data/models/training_preferences_model.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte la valoración entre dominio y base de datos', () {
    final preferences = TrainingPreferences(
      availableDaysPerWeek: 4,
      sessionDurationMinutes: 60,
      targetDate: DateTime(2027, 5, 18),
      experience: TrainingExperience.consistent,
      equipment: const {
        TrainingEquipment.pullUpBar,
        TrainingEquipment.runningTrack,
      },
      requiresProfessionalReview: true,
    );

    final json = TrainingPreferencesModel.toJson(preferences, userId: 'user-1');
    final restored = TrainingPreferencesModel.fromJson(json);

    expect(json['target_date'], '2027-05-18');
    expect(json['experience_level'], 'consistent');
    expect(restored, preferences);
  });

  test('rechaza valores de catálogo desconocidos', () {
    expect(
      () => TrainingPreferencesModel.fromJson({
        'available_days_per_week': 3,
        'session_duration_minutes': 45,
        'target_date': null,
        'experience_level': 'expert',
        'equipment': <String>['none'],
        'requires_professional_review': false,
      }),
      throwsFormatException,
    );
  });
}
