import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('los últimos tres segundos avisan una vez al pausar y repetir', (
    tester,
  ) async {
    var now = Duration.zero;
    final cues = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 40,
            preparationSeconds: 0,
            clock: () => now,
            onElapsedChanged: (_) {},
            onHalfway: () => cues.add('mitad'),
            onTenSecondsRemaining: () => cues.add('diez'),
            onEndingTick: (remaining) => cues.add('$remaining'),
            onFinished: () => cues.add('final'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar temporizador'));
    for (final second in [20, 30, 37, 38]) {
      now = Duration(seconds: second);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(cues, ['mitad', 'diez', '3', '2']);
    await tester.tap(find.text('Pausar'));
    now = const Duration(seconds: 100);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Reanudar'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['mitad', 'diez', '3', '2']);
    for (final second in [101, 102]) {
      now = Duration(seconds: second);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(cues, ['mitad', 'diez', '3', '2', '1', 'final']);
    await tester.tap(find.text('Repetir'));
    for (final second in [139, 140, 141, 142]) {
      now = Duration(seconds: second);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(cues.skip(6), ['3', '2', '1', 'final']);
  });

  testWidgets(
    'restaurar en los últimos segundos no repite el pitido anterior',
    (tester) async {
      final wallNow = DateTime.utc(2026, 10, 8);
      var now = Duration.zero;
      final cues = <String>[];
      final store = _MemoryTimerStore(
        WorkoutTimerSnapshot(
          phase: WorkoutTimerPhase.running,
          targetSeconds: 40,
          preparationSeconds: 0,
          phaseStartedAt: wallNow.subtract(const Duration(seconds: 38)),
          elapsedBeforeRun: Duration.zero,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutSetCountdown(
              targetSeconds: 40,
              preparationSeconds: 0,
              clock: () => now,
              wallClock: () => wallNow,
              timerStore: store,
              timerId: 'set',
              onElapsedChanged: (_) {},
              onEndingTick: (remaining) => cues.add('$remaining'),
              onFinished: () => cues.add('final'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0:02'), findsOneWidget);
      expect(cues, isEmpty);
      now = const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 200));
      now = const Duration(seconds: 2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(cues, ['1', 'final']);
    },
  );

  for (final seconds in [1, 2, 3]) {
    testWidgets(
      'un intervalo de $seconds s no solapa el inicio con la cuenta final',
      (tester) async {
        var now = Duration.zero;
        final cues = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkoutSetCountdown(
                targetSeconds: seconds,
                preparationSeconds: 0,
                clock: () => now,
                onElapsedChanged: (_) {},
                onStarted: () => cues.add('inicio'),
                onEndingTick: (remaining) => cues.add('$remaining'),
                onFinished: () => cues.add('final'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Iniciar temporizador'));
        expect(cues, ['inicio']);
        for (var second = 1; second <= seconds; second++) {
          now = Duration(seconds: second);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(cues, [
          'inicio',
          for (var remaining = seconds - 1; remaining > 0; remaining--)
            '$remaining',
          'final',
        ]);
      },
    );
  }

  testWidgets('mitad y diez segundos no se repiten al pausar y reanudar', (
    tester,
  ) async {
    var now = Duration.zero;
    final cues = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 40,
            preparationSeconds: 0,
            clock: () => now,
            onElapsedChanged: (_) {},
            onHalfway: () => cues.add('mitad'),
            onTenSecondsRemaining: () => cues.add('diez'),
            onFinished: () => cues.add('final'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar temporizador'));
    now = const Duration(seconds: 20);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['mitad']);
    await tester.tap(find.text('Pausar'));
    now = const Duration(seconds: 100);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Reanudar'));
    now = const Duration(seconds: 110);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['mitad', 'diez']);
    now = const Duration(seconds: 120);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['mitad', 'diez', 'final']);
    await tester.tap(find.text('Repetir'));
    now = const Duration(seconds: 140);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues.last, 'mitad');
  });

  for (final seconds in [5, 10, 20]) {
    testWidgets('intervalo de $seconds s no superpone mitad, diez y final', (
      tester,
    ) async {
      var now = Duration.zero;
      final cues = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutSetCountdown(
              targetSeconds: seconds,
              preparationSeconds: 0,
              clock: () => now,
              onElapsedChanged: (_) {},
              onHalfway: () => cues.add('mitad'),
              onTenSecondsRemaining: () => cues.add('diez'),
              onFinished: () => cues.add('final'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Iniciar temporizador'));
      now = Duration(seconds: seconds ~/ 2);
      await tester.pump(const Duration(milliseconds: 200));
      expect(cues, seconds == 20 ? ['diez'] : isEmpty);
      now = Duration(seconds: seconds);
      await tester.pump(const Duration(milliseconds: 200));
      expect(cues, seconds == 20 ? ['diez', 'final'] : ['final']);
    });
  }

  testWidgets('restaurar tras los hitos no reproduce avisos pasados', (
    tester,
  ) async {
    final wallNow = DateTime.utc(2026, 10, 8);
    var now = Duration.zero;
    final cues = <String>[];
    final store = _MemoryTimerStore(
      WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.running,
        targetSeconds: 40,
        preparationSeconds: 0,
        phaseStartedAt: wallNow.subtract(const Duration(seconds: 35)),
        elapsedBeforeRun: Duration.zero,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 40,
            preparationSeconds: 0,
            clock: () => now,
            wallClock: () => wallNow,
            timerStore: store,
            timerId: 'set',
            onElapsedChanged: (_) {},
            onStarted: () => cues.add('inicio'),
            onHalfway: () => cues.add('mitad'),
            onTenSecondsRemaining: () => cues.add('diez'),
            onFinished: () => cues.add('final'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('0:05'), findsOneWidget);
    expect(cues, isEmpty);
    now = const Duration(seconds: 5);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['final']);
  });

  testWidgets('saltar directamente al final emite solo el final', (
    tester,
  ) async {
    var now = Duration.zero;
    final cues = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 40,
            preparationSeconds: 0,
            clock: () => now,
            onElapsedChanged: (_) {},
            onHalfway: () => cues.add('mitad'),
            onTenSecondsRemaining: () => cues.add('diez'),
            onEndingTick: (remaining) => cues.add('$remaining'),
            onFinished: () => cues.add('final'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar temporizador'));
    now = const Duration(seconds: 50);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cues, ['final']);
  });

  testWidgets('cuenta, permite pausar y entrega los segundos realizados', (
    tester,
  ) async {
    var elapsed = -1;
    var now = Duration.zero;
    var preparationTicks = 0;
    var starts = 0;
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 3,
            onElapsedChanged: (value) => elapsed = value,
            onPreparationTick: () => preparationTicks++,
            onStarted: () => starts++,
            onFinished: () => finishes++,
            clock: () => now,
          ),
        ),
      ),
    );

    expect(find.text('0:03'), findsOneWidget);
    await tester.tap(find.text('Iniciar temporizador'));
    await tester.pump();

    expect(find.text('Prepárate…'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(elapsed, 0);
    expect(preparationTicks, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);
    expect(preparationTicks, 3);
    expect(starts, 1);

    now += const Duration(seconds: 1);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('0:02'), findsOneWidget);
    expect(elapsed, 1);

    await tester.tap(find.text('Pausar'));
    now += const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:02'), findsOneWidget);

    await tester.tap(find.text('Reanudar'));
    now += const Duration(seconds: 2);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Tiempo completado'), findsOneWidget);
    expect(elapsed, 3);
    expect(finishes, 1);
  });

  testWidgets('restaura un temporizador activo usando el tiempo transcurrido', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 20, 20);
    final store = _MemoryTimerStore(
      WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.running,
        targetSeconds: 20,
        preparationSeconds: 3,
        phaseStartedAt: now.subtract(const Duration(seconds: 5)),
        elapsedBeforeRun: const Duration(seconds: 2),
      ),
    );
    var elapsed = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 20,
            timerId: 'execution:set',
            timerStore: store,
            wallClock: () => now,
            clock: () => Duration.zero,
            onElapsedChanged: (value) => elapsed = value,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0:13'), findsOneWidget);
    expect(find.text('Realizado: 7 s'), findsOneWidget);
    expect(find.text('Pausar'), findsOneWidget);
    expect(elapsed, 7);
  });

  testWidgets('puede comenzar automáticamente para encadenar minutos EMOM', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 60,
            preparationSeconds: 0,
            autoStart: true,
            title: 'RELOJ EMOM',
            onElapsedChanged: (_) {},
            onStarted: () => starts++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('RELOJ EMOM'), findsOneWidget);
    expect(find.text('Pausar'), findsOneWidget);
    expect(starts, 1);
  });
}

class _MemoryTimerStore implements WorkoutTimerStore {
  _MemoryTimerStore(this.snapshot);

  WorkoutTimerSnapshot? snapshot;

  @override
  Future<void> clear(String timerId) async => snapshot = null;

  @override
  Future<WorkoutTimerSnapshot?> read(String timerId) async => snapshot;

  @override
  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
