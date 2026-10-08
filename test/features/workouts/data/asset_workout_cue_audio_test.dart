import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:entrenaop/features/workouts/data/services/asset_workout_cue_audio.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reutiliza el reproductor, evita avisos obsoletos y recupera errores',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final previousCache = AudioCache.instance;
      AudioCache.instance = _Cache();
      final calls = <MethodCall>[];
      final eventChannels = <String>{};
      var failResume = false;
      Completer<void>? sourceGate;
      Future<void> event(String channel, Map<String, Object> value) async {
        await messenger.handlePlatformMessage(
          channel,
          const StandardMethodCodec().encodeSuccessEnvelope(value),
          (_) {},
        );
      }

      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async {
          calls.add(call);
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final channel =
              'xyz.luan/audioplayers/events/${arguments['playerId']}';
          if (call.method == 'create') {
            eventChannels.add(channel);
            messenger.setMockMethodCallHandler(
              MethodChannel(channel),
              (_) async => null,
            );
          }
          if (call.method == 'setSourceUrl') {
            await sourceGate?.future;
            await event(channel, {'event': 'audio.onPrepared', 'value': true});
          }
          if (call.method == 'resume' && failResume) {
            throw PlatformException(code: 'audio_failed');
          }
          return null;
        },
      );
      final audio = AssetWorkoutCueAudio();
      addTearDown(() async {
        await audio.dispose();
        AudioCache.instance = previousCache;
        for (final channel in eventChannels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
        messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global/events'),
          null,
        );
      });
      await audio.prepare();
      expect(calls.where((call) => call.method == 'resume'), isEmpty);
      await audio.play(WorkoutCue.preparationTick);
      await audio.play(WorkoutCue.workStarted);
      expect(calls.where((call) => call.method == 'create').length, 1);
      expect(calls.where((call) => call.method == 'resume').length, 2);
      sourceGate = Completer<void>();
      final old = audio.play(WorkoutCue.halfway);
      await Future<void>.delayed(Duration.zero);
      final latest = audio.play(WorkoutCue.tenSecondsRemaining);
      sourceGate.complete();
      await Future.wait([old, latest]);
      expect(calls.where((call) => call.method == 'resume').length, 3);
      expect(
        calls
            .lastWhere((call) => call.method == 'setSourceUrl')
            .arguments['url'],
        contains('ten_seconds.wav'),
      );
      failResume = true;
      await expectLater(
        audio.play(WorkoutCue.workFinished),
        throwsA(isA<PlatformException>()),
      );
      failResume = false;
      await expectLater(audio.play(WorkoutCue.restFinished), completes);
      expect(
        calls
            .lastWhere((call) => call.method == 'setSourceUrl')
            .arguments['url'],
        contains('start.wav'),
      );
      final resumes = calls.where((call) => call.method == 'resume').length;
      sourceGate = Completer<void>();
      final lateCue = audio.play(WorkoutCue.halfway);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      sourceGate.complete();
      await lateCue;
      expect(calls.where((call) => call.method == 'resume').length, resumes);
      sourceGate = Completer<void>();
      final preview = audio.play(WorkoutCue.workStarted, allowDelay: true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      sourceGate.complete();
      await preview;
      expect(
        calls.where((call) => call.method == 'resume').length,
        resumes + 1,
      );
    },
  );

  test(
    'todos los avisos tienen un WAV PCM real empaquetado y con señal',
    () async {
      for (final cue in WorkoutCue.values) {
        final asset = AssetWorkoutCueAudio.assets[cue];
        expect(asset, isNotNull, reason: cue.name);
        final data = await rootBundle.load('assets/$asset');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
        expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
        expect(data.getUint16(20, Endian.little), 1); // PCM
        expect(data.getUint16(22, Endian.little), 1); // Mono
        expect(data.getUint32(24, Endian.little), 44100);
        expect(data.getUint16(34, Endian.little), 16);
        expect(bytes.length, greaterThan(8000));
        expect(bytes.skip(44).any((sample) => sample != 0), isTrue);
      }
    },
  );
}

class _Cache extends AudioCache {
  @override
  Future<Uri> fetchToMemory(String fileName) async =>
      Uri.file('/workout-cues/$fileName');
}
