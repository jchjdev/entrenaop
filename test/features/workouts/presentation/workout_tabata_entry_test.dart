import 'dart:async';

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_tabata_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Duration now;
  late _Store store;
  late _Cues cues;
  late List<String> ended;
  final wall = DateTime.utc(2026, 10, 19);

  setUp(() {
    now = Duration.zero;
    store = _Store();
    cues = _Cues();
    ended = [];
  });

  Future<void> show(
    WidgetTester tester, {
    Future<bool> Function(String)? onEnd,
    List<WorkoutExecutionSet>? sets,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: WorkoutTabataEntry(
            executionId: 'execution',
            sets: sets ?? tabataSets(),
            exercises: const {},
            timerStore: store,
            cueService: cues,
            clock: () => now,
            wallClock: () => wall.add(now),
            onIntervalEnded:
                onEnd ??
                (id) async {
                  ended.add(id);
                  return true;
                },
            records: const Text('Series y registros'),
          ),
        ),
      ),
    ),
  );

  Future<void> advance(WidgetTester tester, int seconds) async {
    now += Duration(seconds: seconds);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('Iniciar Tabata'));
    await tester.pump();
  }

  testWidgets(
    'un inicio encadena 8 trabajos y recuperaciones, incluida la última',
    (tester) async {
      await show(tester);
      await start(tester);
      expect(find.text('Prepárate…'), findsOneWidget);
      await advance(tester, 3);
      expect(find.text('Trabajo'), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        expect(find.text('Intervalo ${i + 1} de 8'), findsOneWidget);
        await advance(tester, 20);
        expect(find.text('Recuperación'), findsOneWidget);
        expect(ended.length, i == 7 ? 7 : i + 1);
        await advance(tester, 10);
      }
      expect(ended, List.generate(8, (i) => 'set-$i'));
      expect(find.text('Tabata completado'), findsOneWidget);
      expect(store.snapshots, isEmpty);
      expect(cues.signals.where((c) => c == WorkoutCue.workStarted).length, 8);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final pauseAt in [1, 8, 27]) {
    testWidgets('pausa y reanuda sin consumir tiempo en el segundo $pauseAt', (
      tester,
    ) async {
      await show(tester);
      await start(tester);
      await advance(tester, pauseAt);
      final count = ended.length;
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      await advance(tester, 90);
      expect(ended.length, count);
      expect(find.text('En pausa'), findsOneWidget);
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      await advance(tester, 243 - pauseAt);
      expect(ended.length, 8);
      expect(find.text('Tabata completado'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'retoma una recuperación pausada sin saltarla ni repetir trabajo',
    (tester) async {
      store.snapshots['execution:tabata:0'] = WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.paused,
        targetSeconds: 243,
        preparationSeconds: 0,
        phaseStartedAt: wall,
        elapsedBeforeRun: const Duration(seconds: 28),
      );
      final sets = tabataSets();
      sets[0] = sets[0].copyWith(status: WorkoutSetStatus.completed);
      await show(tester, sets: sets);
      await tester.pump();
      expect(find.text('00:05'), findsOneWidget);
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      await advance(tester, 5);
      expect(find.text('Intervalo 2 de 8'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      expect(ended, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('recupera el reloj corrido sin ráfagas de avisos antiguos', (
    tester,
  ) async {
    now = const Duration(seconds: 68);
    store.snapshots['execution:tabata:0'] = WorkoutTimerSnapshot(
      phase: WorkoutTimerPhase.running,
      targetSeconds: 243,
      preparationSeconds: 0,
      phaseStartedAt: wall,
      elapsedBeforeRun: Duration.zero,
    );
    await show(tester);
    await tester.pump();
    expect(find.text('Intervalo 3 de 8'), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);
    expect(ended, ['set-0', 'set-1']);
    expect(cues.signals, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un guardado lento no añade tiempo entre intervalos', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await show(
      tester,
      onEnd: (id) async {
        ended.add(id);
        return id == 'set-0' ? pending.future : true;
      },
    );
    await start(tester);
    await advance(tester, 23);
    await advance(tester, 15);
    pending.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Intervalo 2 de 8'), findsOneWidget);
    expect(find.text('00:15'), findsOneWidget);
    expect(ended, ['set-0']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'un fallo de borrador pausa y permite reintentar el mismo intervalo',
    (tester) async {
      var fail = true;
      await show(
        tester,
        onEnd: (id) async {
          if (fail) return false;
          ended.add(id);
          return true;
        },
      );
      await start(tester);
      await advance(tester, 23);
      expect(find.text('En pausa'), findsOneWidget);
      expect(find.textContaining('No se ha podido conservar'), findsOneWidget);
      await advance(tester, 60);
      expect(ended, isEmpty);
      fail = false;
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      expect(ended, ['set-0']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('no arranca si no puede conservar el reloj', (tester) async {
    await show(tester);
    store.failWrite = true;
    await start(tester);
    expect(find.text('En pausa'), findsOneWidget);
    await advance(tester, 243);
    expect(ended, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('320 px y texto doble mantienen el control accesible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, textScale: 2);
    await start(tester);
    expect(find.text('Pausar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

List<WorkoutExecutionSet> tabataSets() => List.generate(
  8,
  (i) => WorkoutExecutionSet(
    id: 'set-$i',
    blockOrder: 0,
    blockName: 'Tabata',
    blockFormat: WorkoutBlockFormat.tabata,
    itemOrder: i,
    exerciseId: 'exercise-${i % 2}',
    exerciseName: i.isEven ? 'Sentadillas' : 'Flexiones',
    setOrder: 0,
    targetDurationSeconds: 20,
    restAfterSeconds: 10,
    status: WorkoutSetStatus.pending,
  ),
);

class _Store implements WorkoutTimerStore {
  final snapshots = <String, WorkoutTimerSnapshot>{};
  bool failWrite = false;
  @override
  Future<WorkoutTimerSnapshot?> read(String timerId) async =>
      snapshots[timerId];
  @override
  Future<void> clear(String timerId) async {
    snapshots.remove(timerId);
  }

  @override
  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot) async {
    if (failWrite) throw StateError('Disco lleno');
    snapshots[timerId] = snapshot;
  }
}

class _Cues implements WorkoutCueService {
  final signals = <WorkoutCue>[];
  @override
  Future<void> signal(WorkoutCue cue) async {
    signals.add(cue);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
