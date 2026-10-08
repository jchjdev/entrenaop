import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformWorkoutCueHaptics {
  static const _channel = MethodChannel('es.entrenaop/workout_vibration');

  static Future<void> signal(WorkoutCue cue) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Los avisos del reloj necesitan pulsos perceptibles, no los efectos
      // de teclado de HapticFeedback, sujetos al ajuste de respuesta táctil.
      final available = await _channel.invokeMethod<bool>('signal', cue.name);
      if (available != true) {
        throw UnsupportedError('El dispositivo no dispone de vibración.');
      }
      return;
    }

    switch (cue) {
      case WorkoutCue.preparationTick:
      case WorkoutCue.workEndingTick:
        await HapticFeedback.selectionClick();
      case WorkoutCue.workStarted:
      case WorkoutCue.workFinished:
      case WorkoutCue.restFinished:
        await HapticFeedback.mediumImpact();
      case WorkoutCue.halfway:
      case WorkoutCue.tenSecondsRemaining:
        await HapticFeedback.lightImpact();
    }
  }
}
