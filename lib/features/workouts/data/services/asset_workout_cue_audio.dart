import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';

abstract class WorkoutCueAudio {
  Future<void> prepare();
  Future<void> play(WorkoutCue cue, {bool allowDelay = false});
  Future<void> dispose();
}

/// Un solo reproductor reutilizable evita superponer avisos y conserva el
/// contexto de audio que el navegador activa tras la interacción del usuario.
class AssetWorkoutCueAudio implements WorkoutCueAudio {
  AssetWorkoutCueAudio({AudioPlayer? player}) : _player = player;

  static const assets = <WorkoutCue, String>{
    WorkoutCue.preparationTick: 'audio/workout/preparation.wav',
    WorkoutCue.workStarted: 'audio/workout/start.wav',
    WorkoutCue.halfway: 'audio/workout/halfway.wav',
    WorkoutCue.tenSecondsRemaining: 'audio/workout/ten_seconds.wav',
    WorkoutCue.workFinished: 'audio/workout/finish.wav',
    WorkoutCue.restFinished: 'audio/workout/start.wav',
  };

  AudioPlayer? _player;
  Future<void>? _preparing;
  Future<void> _tail = Future.value();
  int _generation = 0;
  bool _disposed = false;

  @override
  Future<void> prepare() {
    if (_disposed) return Future.value();
    return _preparing ??= _prepare().catchError((Object error) {
      _preparing = null;
      throw error;
    });
  }

  Future<void> _prepare() async {
    final player = _player ??= AudioPlayer()..positionUpdater = null;
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await player.setReleaseMode(ReleaseMode.stop);
    await player.audioCache.loadAll(assets.values.toSet().toList());
    await player.setSource(AssetSource(assets[WorkoutCue.preparationTick]!));
  }

  @override
  Future<void> play(WorkoutCue cue, {bool allowDelay = false}) {
    if (_disposed) return Future.error(StateError('Reproductor cerrado'));
    final generation = ++_generation;
    final requestedAt = DateTime.now();
    final operation = _tail.then((_) async {
      await prepare();
      bool current() =>
          !_disposed &&
          generation == _generation &&
          (allowDelay ||
              DateTime.now().difference(requestedAt) <
                  const Duration(seconds: 1));
      // Un aviso retrasado por la carga no debe sonar en la fase siguiente.
      if (!current()) return;
      final player = _player!;
      await player.stop();
      await player.setSource(AssetSource(assets[cue]!));
      if (!current()) return;
      await player.resume();
    });
    // Un fallo no deja inutilizado el reproductor para los avisos siguientes.
    _tail = operation.then((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await _tail;
    await _preparing?.onError((_, _) {});
    await _player?.dispose();
  }
}
