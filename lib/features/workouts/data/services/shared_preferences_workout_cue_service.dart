import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/data/services/asset_workout_cue_audio.dart';
import 'package:entrenaop/features/workouts/data/services/platform_workout_cue_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutCueService implements WorkoutCueService {
  SharedPreferencesWorkoutCueService(
    this._preferences, {
    WorkoutCueAudio? audio,
    Future<void> Function(WorkoutCue)? haptic,
  }) : _audio = audio ?? AssetWorkoutCueAudio(),
       _haptic = haptic ?? PlatformWorkoutCueHaptics.signal,
       _usesPlatformHaptic = haptic == null;

  static const _soundKey = 'workout_cues.sound_enabled';
  static const _hapticsKey = 'workout_cues.haptics_enabled';

  final SharedPreferences _preferences;
  final WorkoutCueAudio _audio;
  final Future<void> Function(WorkoutCue) _haptic;
  final bool _usesPlatformHaptic;

  @override
  Future<void> prepare() async {
    if (preferences.soundEnabled) await _guard(_audio.prepare);
  }

  @override
  Future<bool> previewSound() async {
    try {
      await _audio.play(WorkoutCue.workStarted, allowDelay: true);
      return true;
    } catch (error) {
      debugPrint('No se ha podido reproducir el aviso: $error');
      return false;
    }
  }

  Future<void> dispose() => _audio.dispose();

  @override
  Future<bool> previewHaptics() async {
    try {
      if (kDebugMode) {
        debugPrint('EntrenaOPVibration: prueba manual iniciada');
        if (_usesPlatformHaptic) {
          await PlatformWorkoutCueHaptics.debugDescribe();
        }
      }
      await _haptic(WorkoutCue.workFinished);
      if (kDebugMode) {
        debugPrint(
          'EntrenaOPVibration: prueba terminada; solicitud sin error, '
          'percepción física sin confirmar',
        );
      }
      return true;
    } catch (error) {
      debugPrint(
        'EntrenaOPVibration: no se ha podido probar la vibración: $error',
      );
      return false;
    }
  }

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
    // Sonido y vibración son independientes; sus fallos nunca interrumpen
    // temporizadores, resultados ni guardados, incluso con llamadas unawaited.
    await Future.wait([
      if (current.soundEnabled) _guard(() => _audio.play(cue)),
      if (current.hapticsEnabled) _guard(() => _haptic(cue)),
    ]);
  }

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('No se ha podido emitir el aviso del temporizador: $error');
    }
  }
}
