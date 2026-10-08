import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/data/services/asset_workout_cue_audio.dart';
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

  test('sonido y vibración se activan de forma independiente', () async {
    final prefs = await SharedPreferences.getInstance();
    final audio = _Audio();
    final haptics = <WorkoutCue>[];
    final service = SharedPreferencesWorkoutCueService(
      prefs,
      audio: audio,
      haptic: (cue) async => haptics.add(cue),
    );
    await service.savePreferences(
      const WorkoutCuePreferences(hapticsEnabled: false),
    );
    await service.signal(WorkoutCue.workStarted);
    expect(audio.cues, [WorkoutCue.workStarted]);
    expect(haptics, isEmpty);
    await service.savePreferences(
      const WorkoutCuePreferences(soundEnabled: false),
    );
    await service.signal(WorkoutCue.workFinished);
    expect(audio.cues, [WorkoutCue.workStarted]);
    expect(haptics, [WorkoutCue.workFinished]);
    await service.savePreferences(
      const WorkoutCuePreferences(soundEnabled: false, hapticsEnabled: false),
    );
    await service.signal(WorkoutCue.restFinished);
    expect(audio.cues.length, 1);
    expect(haptics.length, 1);
    expect(
      SharedPreferencesWorkoutCueService(prefs).preferences,
      service.preferences,
    );
  });

  test(
    'un fallo de audio no impide vibrar ni los avisos posteriores',
    () async {
      final audio = _Audio()..fail = true;
      final haptics = <WorkoutCue>[];
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
        haptic: (cue) async => haptics.add(cue),
      );
      await service.prepare();
      await expectLater(service.signal(WorkoutCue.halfway), completes);
      expect(haptics, [WorkoutCue.halfway]);
      expect(await service.previewSound(), isFalse);
      audio.fail = false;
      await service.signal(WorkoutCue.tenSecondsRemaining);
      expect(haptics.last, WorkoutCue.tenSecondsRemaining);
      expect(audio.cues.last, WorkoutCue.tenSecondsRemaining);
    },
  );

  test(
    'la prueba explícita suena sin cambiar ni guardar el borrador',
    () async {
      final audio = _Audio();
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
        haptic: (_) async => throw StateError('No hay vibración'),
      );
      await service.savePreferences(
        const WorkoutCuePreferences(soundEnabled: false),
      );
      expect(await service.previewSound(), isTrue);
      expect(audio.cues, [WorkoutCue.workStarted]);
      expect(service.preferences.soundEnabled, isFalse);
      await service.savePreferences(const WorkoutCuePreferences());
      await expectLater(service.signal(WorkoutCue.restFinished), completes);
      expect(audio.cues.last, WorkoutCue.restFinished);
    },
  );
}

class _Audio implements WorkoutCueAudio {
  final cues = <WorkoutCue>[];
  bool fail = false;

  @override
  Future<void> prepare() async {
    if (fail) throw StateError('No se ha podido cargar');
  }

  @override
  Future<void> play(WorkoutCue cue, {bool allowDelay = false}) async {
    if (fail) throw StateError('No se ha podido reproducir');
    cues.add(cue);
  }

  @override
  Future<void> dispose() async {}
}
