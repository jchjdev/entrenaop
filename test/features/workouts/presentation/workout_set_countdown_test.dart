import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
