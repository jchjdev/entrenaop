import 'dart:async';

import 'package:entrenaop/features/workouts/data/services/platform_workout_cue_haptics.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('es.entrenaop/workout_vibration');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'Android envía todos los hitos al motor sin efectos de teclado',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final cues = <String>[];
      final interfaceEffects = <MethodCall>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        expect(call.method, 'signal');
        cues.add(call.arguments as String);
        return true;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        interfaceEffects.add(call);
        return null;
      });
      for (final cue in WorkoutCue.values) {
        await PlatformWorkoutCueHaptics.signal(cue);
      }
      expect(cues, WorkoutCue.values.map((cue) => cue.name));
      expect(interfaceEffects, isEmpty);
    },
  );

  test('no acredita vibración cuando Android no tiene motor', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(native, (_) async => false);
    await expectLater(
      PlatformWorkoutCueHaptics.signal(WorkoutCue.workFinished),
      throwsUnsupportedError,
    );
  });

  test('la prueba espera el permiso antes de solicitar la vibración', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final permission = Completer<bool>();
    final methods = <String>[];
    messenger.setMockMethodCallHandler(native, (call) async {
      methods.add(call.method);
      if (call.method == 'requestPermission') return permission.future;
      expect(call.arguments, WorkoutCue.workFinished.name);
      return true;
    });
    final preview = PlatformWorkoutCueHaptics.preview();
    await Future<void>.delayed(Duration.zero);
    expect(methods, ['requestPermission']);
    permission.complete(true);
    await preview;
    expect(methods, ['requestPermission', 'signal']);
  });

  test(
    'denegar permiso no solicita vibración ni usa efectos de teclado',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        methods.add(call.method);
        return false;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        fail('No debe eludir la denegación mediante efectos de teclado');
      });
      await expectLater(
        PlatformWorkoutCueHaptics.preview(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'notifications_disabled',
          ),
        ),
      );
      expect(methods, ['requestPermission']);
    },
  );

  test(
    'propaga un fallo nativo para comunicarlo en la prueba manual',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(native, (_) async {
        throw PlatformException(code: 'vibration_failed');
      });
      await expectLater(
        PlatformWorkoutCueHaptics.signal(WorkoutCue.workFinished),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'iOS usa el motor nativo para todos los hitos sin pedir permiso',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final cues = <String>[];
      messenger.setMockMethodCallHandler(native, (call) async {
        expect(call.method, 'signal');
        cues.add(call.arguments as String);
        return true;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        fail('Los avisos iOS no deben volver a los toques de interfaz');
      });
      expect(await PlatformWorkoutCueHaptics.needsPermission(), isFalse);
      expect(await PlatformWorkoutCueHaptics.requestPermission(), isTrue);
      for (final cue in WorkoutCue.values) {
        await PlatformWorkoutCueHaptics.signal(cue);
      }
      await PlatformWorkoutCueHaptics.preview();
      expect(cues, [
        ...WorkoutCue.values.map((cue) => cue.name),
        WorkoutCue.workFinished.name,
      ]);
    },
  );

  test('iOS sin motor comunica que la prueba no está disponible', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(native, (_) async => false);
    await expectLater(
      PlatformWorkoutCueHaptics.preview(),
      throwsUnsupportedError,
    );
  });

  test('un error de Core Haptics se propaga sin simular éxito', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(native, (_) async {
      throw PlatformException(code: 'haptics_failed');
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
      fail('No se debe ocultar el error con otro efecto de interfaz');
    });
    await expectLater(
      PlatformWorkoutCueHaptics.preview(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('un diagnóstico ausente no impide emitir el aviso de Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final methods = <String>[];
    messenger.setMockMethodCallHandler(native, (call) async {
      methods.add(call.method);
      if (call.method == 'diagnostics') {
        throw PlatformException(code: 'diagnostic_failed');
      }
      return true;
    });
    await expectLater(PlatformWorkoutCueHaptics.debugDescribe(), completes);
    await expectLater(
      PlatformWorkoutCueHaptics.signal(WorkoutCue.workFinished),
      completes,
    );
    expect(methods, ['diagnostics', 'signal']);
  });
}
