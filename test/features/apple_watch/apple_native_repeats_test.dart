import 'package:entrenaop/features/apple_watch/data/apple_training_adapters.dart';
import 'package:entrenaop/features/apple_watch/domain/apple_training.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('es.entrenaop.device_health/reader');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'apple.schedule' => {'submitted': true},
            'apple.inspect' => {'state': 'matching'},
            'apple.results.read' => {'observations': []},
            _ => throw StateError('Operación inesperada'),
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'programar, verificar y leer resultados conservan el mismo grupo nativo',
    () async {
      const work = AppleStep('run', 'meters', 400, 'Carrera', 230, 240);
      const rest = AppleStep('rest', 'seconds', 45, 'Recuperación', null, null);
      final plan = ApplePlan(
        ApplePrescription(
          'Series',
          '2026-11-04',
          [
            for (var i = 0; i < 10; i++) ...[work, rest],
          ],
          repeatBlocks: const [AppleRepeatBlock(0, 2, 10, false)],
        ),
        'revision',
        'plan',
        'attempt',
      );
      const scheduler = NativeAppleWorkoutScheduler();
      await scheduler.schedule('owner', plan);
      expect(
        await scheduler.inspect('owner', plan),
        AppleScheduledState.matching,
      );
      await const NativeAppleResultsReader().read([plan]);
      final scheduled = calls[0].arguments['prescription'] as Map;
      final inspected = calls[1].arguments['prescription'] as Map;
      final read = calls[2].arguments['plans'][0]['prescription'] as Map;
      expect(scheduled['steps'], hasLength(20));
      expect(scheduled['repeat_blocks'], [
        {
          'start': 0,
          'step_count': 2,
          'iterations': 10,
          'omit_last_recovery': false,
        },
      ]);
      expect(inspected, scheduled);
      expect(read, scheduled);
      expect(calls[0].arguments['owner'], isNot('owner'));
    },
  );

  test(
    'una receta anterior conserva los pasos sin metadatos nuevos obligatorios',
    () async {
      final plan = ApplePlan(
        ApplePrescription('Anterior', '2026-11-04', const [
          AppleStep('run', 'seconds', 120, 'Carrera', null, null),
        ]),
        'revision',
        'plan',
        'attempt',
      );
      await const NativeAppleWorkoutScheduler().schedule('owner', plan);
      expect(
        (calls.single.arguments['prescription'] as Map).containsKey(
          'repeat_blocks',
        ),
        isFalse,
      );
    },
  );
}
