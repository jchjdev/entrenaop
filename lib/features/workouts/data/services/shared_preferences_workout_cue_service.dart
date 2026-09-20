import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutCueService implements WorkoutCueService {
  SharedPreferencesWorkoutCueService(this._preferences);

  static const _soundKey = 'workout_cues.sound_enabled';
  static const _hapticsKey = 'workout_cues.haptics_enabled';

  final SharedPreferences _preferences;

  @override
  WorkoutCuePreferences get preferences => WorkoutCuePreferences(
    soundEnabled: _preferences.getBool(_soundKey) ?? true,
    hapticsEnabled: _preferences.getBool(_hapticsKey) ?? true,
  );

  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async {
    await Future.wait([
      _preferences.setBool(_soundKey, preferences.soundEnabled),
      _preferences.setBool(_hapticsKey, preferences.hapticsEnabled),
    ]);
  }

  @override
  Future<void> signal(WorkoutCue cue) async {
    final current = preferences;
    if (current.soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (!current.hapticsEnabled) return;
    switch (cue) {
      case WorkoutCue.preparationTick:
        await HapticFeedback.selectionClick();
      case WorkoutCue.workStarted:
      case WorkoutCue.workFinished:
      case WorkoutCue.restFinished:
        await HapticFeedback.mediumImpact();
    }
  }
}
