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

  test('iOS conserva los efectos del sistema sin canal Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final effects = <String>[];
    messenger.setMockMethodCallHandler(native, (_) async {
      fail('iOS no debe usar el adaptador Android');
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      expect(call.method, 'HapticFeedback.vibrate');
      effects.add(call.arguments as String);
      return null;
    });
    await PlatformWorkoutCueHaptics.signal(WorkoutCue.preparationTick);
    await PlatformWorkoutCueHaptics.signal(WorkoutCue.workFinished);
    await PlatformWorkoutCueHaptics.signal(WorkoutCue.halfway);
    expect(effects, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
    ]);
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
