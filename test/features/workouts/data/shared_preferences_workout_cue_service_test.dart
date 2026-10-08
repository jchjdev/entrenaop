import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/data/services/asset_workout_cue_audio.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  const native = MethodChannel('es.entrenaop/workout_vibration');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(native, null);
  });

  test(
    'ofrecer no pide permiso ni emite avisos y no se repite entre instancias',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        methods.add(call.method);
        expect(call.method, 'needsPermission');
        return true;
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesWorkoutCueService(
        prefs,
        audio: _Audio(),
      );
      expect(await service.shouldOfferHapticsPermission(), isTrue);
      await service.markHapticsPermissionOffered();
      expect(await service.shouldOfferHapticsPermission(), isFalse);
      expect(
        await SharedPreferencesWorkoutCueService(
          prefs,
          audio: _Audio(),
        ).shouldOfferHapticsPermission(),
        isFalse,
      );
      expect(methods, ['needsPermission']);
      expect(service.preferences, const WorkoutCuePreferences());
    },
  );

  test('no ofrece permiso con vibración desactivada o ya concedido', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final methods = <String>[];
    messenger.setMockMethodCallHandler(native, (call) async {
      methods.add(call.method);
      return false;
    });
    final service = SharedPreferencesWorkoutCueService(
      await SharedPreferences.getInstance(),
      audio: _Audio(),
    );
    await service.savePreferences(
      const WorkoutCuePreferences(hapticsEnabled: false),
    );
    expect(await service.shouldOfferHapticsPermission(), isFalse);
    expect(methods, isEmpty);
    await service.savePreferences(const WorkoutCuePreferences());
    expect(await service.shouldOfferHapticsPermission(), isFalse);
    expect(methods, ['needsPermission']);
  });

  test(
    'la petición denegada no guarda preferencias ni insiste automáticamente',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        methods.add(call.method);
        expect(call.method, 'requestPermission');
        return false;
      });
      final audio = _Audio();
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
      );
      expect(await service.requestHapticsPermission(), isFalse);
      expect(await service.shouldOfferHapticsPermission(), isFalse);
      expect(audio.cues, isEmpty);
      expect(service.preferences, const WorkoutCuePreferences());
      expect(methods, ['requestPermission']);
    },
  );

  test('fallar el canal de permisos no impide abrir la sesión', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(native, (_) async {
      throw PlatformException(code: 'permission_failed');
    });
    final service = SharedPreferencesWorkoutCueService(
      await SharedPreferences.getInstance(),
      audio: _Audio(),
    );
    expect(await service.shouldOfferHapticsPermission(), isFalse);
    expect(await service.requestHapticsPermission(), isFalse);
    expect(await service.shouldOfferHapticsPermission(), isFalse);
  });

  test('iOS no ofrece ni pide el permiso Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(native, (_) async {
      fail('iOS no debe consultar el canal de permisos Android');
    });
    final service = SharedPreferencesWorkoutCueService(
      await SharedPreferences.getInstance(),
      audio: _Audio(),
    );
    expect(await service.shouldOfferHapticsPermission(), isFalse);
    expect(await service.requestHapticsPermission(), isTrue);
  });

  test(
    'denegar notificaciones falla la prueba sin bloquear reloj ni sonido',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        methods.add(call.method);
        if (call.method == 'diagnostics') {
          return {'notificationsEnabled': false};
        }
        if (call.method == 'requestPermission') return false;
        throw PlatformException(code: 'notifications_disabled');
      });
      final audio = _Audio();
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
      );
      expect(await service.previewHaptics(), isFalse);
      expect(methods, ['diagnostics', 'requestPermission']);
      expect(audio.cues, isEmpty);
      await expectLater(service.signal(WorkoutCue.workStarted), completes);
      expect(audio.cues, [WorkoutCue.workStarted]);
      expect(methods, ['diagnostics', 'requestPermission', 'signal']);
      expect(service.preferences, const WorkoutCuePreferences());
    },
  );

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

  test(
    'probar vibración no suena ni modifica preferencias desactivadas',
    () async {
      final audio = _Audio();
      final haptics = <WorkoutCue>[];
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
        haptic: (cue) async => haptics.add(cue),
      );
      const disabled = WorkoutCuePreferences(
        soundEnabled: false,
        hapticsEnabled: false,
      );
      await service.savePreferences(disabled);
      expect(await service.previewHaptics(), isTrue);
      expect(haptics, [WorkoutCue.workFinished]);
      expect(audio.cues, isEmpty);
      expect(service.preferences, disabled);
    },
  );

  test(
    'un fallo háptico se comunica al probar y no detiene el sonido',
    () async {
      final audio = _Audio();
      final service = SharedPreferencesWorkoutCueService(
        await SharedPreferences.getInstance(),
        audio: audio,
        haptic: (_) async => throw StateError('No hay motor disponible'),
      );
      expect(await service.previewHaptics(), isFalse);
      await expectLater(service.signal(WorkoutCue.workStarted), completes);
      expect(audio.cues, [WorkoutCue.workStarted]);
      expect(service.preferences, const WorkoutCuePreferences());
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
