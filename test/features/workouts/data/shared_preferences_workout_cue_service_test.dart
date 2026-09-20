import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'los avisos están activos por defecto y conservan la configuración',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final service = SharedPreferencesWorkoutCueService(preferences);

      expect(service.preferences, const WorkoutCuePreferences());

      await service.savePreferences(
        const WorkoutCuePreferences(soundEnabled: false, hapticsEnabled: true),
      );

      expect(
        service.preferences,
        const WorkoutCuePreferences(soundEnabled: false, hapticsEnabled: true),
      );
    },
  );
}
