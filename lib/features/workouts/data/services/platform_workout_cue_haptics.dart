import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformWorkoutCueHaptics {
  static const _channel = MethodChannel('es.entrenaop/workout_vibration');

  static Future<bool> needsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return await _channel.invokeMethod<bool>('needsPermission') == true;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    return await _channel.invokeMethod<bool>('requestPermission') == true;
  }

  static Future<void> preview() async {
    // Solo una acción explícita pide permiso; los hitos del reloj nunca
    // abren diálogos ni interrumpen el entrenamiento.
    if (!await requestPermission()) {
      throw PlatformException(code: 'notifications_disabled');
    }
    await signal(WorkoutCue.workFinished);
  }

  static Future<void> debugDescribe() async {
    if (!kDebugMode) return;
    debugPrint(
      'EntrenaOPVibration: plataforma=${defaultTargetPlatform.name}, web=$kIsWeb',
    );
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await _channel
          .invokeMapMethod<String, dynamic>('diagnostics')
          .timeout(const Duration(seconds: 2));
      debugPrint('EntrenaOPVibration: diagnóstico Android=$info');
    } catch (error) {
      // El diagnóstico nunca impide probar el motor, incluso en un APK que
      // aún conserve el canal nativo anterior.
      debugPrint('EntrenaOPVibration: diagnóstico no disponible: $error');
    }
  }

  static Future<void> signal(WorkoutCue cue) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Los avisos del reloj necesitan pulsos perceptibles, no los efectos
      // de teclado de HapticFeedback, sujetos al ajuste de respuesta táctil.
      final available = await _channel.invokeMethod<bool>('signal', cue.name);
      if (kDebugMode) {
        debugPrint(
          'EntrenaOPVibration: aviso=${cue.name}, solicitud enviada=$available',
        );
      }
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
