import 'package:flutter/services.dart';

import '../../domain/services/workout_lock_screen.dart';

class MethodChannelWorkoutLockScreen implements WorkoutLockScreen {
  const MethodChannelWorkoutLockScreen();

  static const _channel = MethodChannel('es.entrenaop/workout_lock_screen');

  @override
  Future<bool> show(WorkoutLockScreenSnapshot snapshot) async {
    try {
      return await _channel.invokeMethod<bool>('show', {
            'executionId': snapshot.executionId,
            'exercise': snapshot.exercise,
            'prescription': snapshot.prescription,
            'restEndsAt': snapshot.restEndsAt?.millisecondsSinceEpoch,
            'openUrl': Uri(
              scheme: 'es.entrenaop',
              host: 'workout-session',
              pathSegments: [snapshot.executionId],
            ).toString(),
          }) ??
          true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> clear(String executionId) async {
    try {
      await _channel.invokeMethod<void>('clear', executionId);
    } on MissingPluginException {
      // El bloqueo es una vista auxiliar, también disponible en builds nativos.
    } on PlatformException {
      // El estado y registro de la sesión se conservan en el ejecutor.
    }
  }
}
