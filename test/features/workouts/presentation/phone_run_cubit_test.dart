import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/services/phone_run_plan.dart';
import 'package:entrenaop/features/workouts/domain/services/phone_running.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/phone_run_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/phone_run_panel.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_execution_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/running_step.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);

  for (final (width, scale) in [(390.0, 1.0), (320.0, 1.8)]) {
    testWidgets('el ritmo se distingue del tiempo con escala $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 840);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final location = _Location();
      addTearDown(location.events.close);
      var now = DateTime.utc(2026, 11, 23);
      final cubit = PhoneRunCubit(
        executionId: 'series',
        location: location,
        checkpoints: _Checkpoints(),
        now: () => now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: scale == 1 ? EntrenaTheme.dark : EntrenaTheme.light,
          home: Scaffold(
            appBar: AppBar(title: const Text('Registrar carrera')),
            body: RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: PhoneRunPanel(
                createRecorder: () => cubit,
                set: const WorkoutExecutionSet(
                  id: 'serie',
                  blockOrder: 0,
                  blockName: 'Series',
                  itemOrder: 0,
                  exerciseId: 'carrera',
                  exerciseName: 'Carrera',
                  setOrder: 0,
                  restAfterSeconds: 0,
                  status: WorkoutSetStatus.pending,
                ),
                steps: const [
                  PhoneRunStep(
                    setId: 'serie',
                    kind: RunningStepKind.run,
                    completion: RunningStepCompletion.distance,
                    meters: 400,
                  ),
                ],
                onSave: (_) async => true,
                onManual: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ritmo reciente'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Ritmo pendiente')), findsWidgets);
      await cubit.start();
      await tester.pumpAndSettle();
      for (var second = 0; second <= 24; second++) {
        if (second > 0) now = now.add(const Duration(seconds: 1));
        location.fix(now, second * 3.5 / 111195);
      }
      await tester.pumpAndSettle();
      final pace = find.text(workoutClock(cubit.state.recentPace!));
      final time = find.text('00:24');
      expect(tester.getTopLeft(pace).dy, lessThan(tester.getTopLeft(time).dy));
      expect(
        tester.widget<Text>(pace).style!.fontSize!,
        greaterThan(tester.widget<Text>(time).style!.fontSize!),
      );
      expect(find.text('min/km'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturePerformanceWidget(tester, 'phone-run-${width.toInt()}');

      await cubit.review();
      await tester.pumpAndSettle();
      expect(find.text('Ritmo medio del tramo'), findsOneWidget);
      expect(find.text('Ritmo reciente'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('encadena diez series por distancia y recuperaciones sin duplicar la vuelta', () async {
    final location = _Location();
    final checkpoints = _Checkpoints();
    final cues = _Cues();
    var now = DateTime.utc(2026, 11, 23, 9);
    var position = 0.0;
    final steps = [
      for (var i = 1; i <= 10; i++) ...[
        PhoneRunStep(
          setId: 'serie-$i',
          kind: RunningStepKind.run,
          completion: RunningStepCompletion.distance,
          meters: 400,
        ),
        PhoneRunStep(
          setId: 'serie-$i',
          kind: RunningStepKind.rest,
          completion: RunningStepCompletion.time,
          seconds: 45,
          associatedRecovery: true,
        ),
      ],
    ];
    final cubit = PhoneRunCubit(
      executionId: 'series',
      location: location,
      checkpoints: checkpoints,
      now: () => now,
      cues: cues,
    );
    addTearDown(location.events.close);
    addTearDown(cubit.close);
    await cubit.open(steps: steps);
    expect(cubit.state.phase, PhoneRunPhase.idle);
    expect(location.starts, isEmpty);
    await cubit.start();
    location.fix(now, position);

    for (var i = 1; i <= 10; i++) {
      expect(cubit.state.step?.id, 'serie-$i');
      for (
        var sec = 0;
        sec < 100 && cubit.state.step?.id == 'serie-$i';
        sec++
      ) {
        now = now.add(const Duration(seconds: 1));
        position += 4.1 / 111195;
        location.fix(now, position);
      }
      expect(cubit.state.step?.id, 'serie-$i/recovery');
      expect(cubit.laps.last.totals.distanceMeters, greaterThanOrEqualTo(400));
      cubit.markLap('serie-$i');
      expect(cubit.state.step?.id, 'serie-$i/recovery');
      for (var sec = 0; sec < 45; sec++) {
        now = now.add(const Duration(seconds: 1));
        location.fix(now, position);
      }
    }
    await cubit.stream.firstWhere(
      (state) => state.phase == PhoneRunPhase.review,
    );
    expect(cubit.laps, hasLength(20));
    expect(cubit.laps.last.totals.seconds, 45);
    expect(
      cues.events.where((cue) => cue == WorkoutCue.preparationTick),
      hasLength(30),
    );
    expect(
      cues.events.where((cue) => cue == WorkoutCue.workFinished),
      hasLength(11),
    );
    expect(location.starts, hasLength(1));
    expect(location.stops, location.starts);
    expect(checkpoints.saved?.laps, hasLength(20));
  });

  test(
    'en pista espera la vuelta y anuncia parciales medidos sin repetirlos',
    () async {
      final location = _Location();
      final feedback = _Feedback();
      final checkpoints = _Checkpoints();
      var now = DateTime.utc(2026, 11, 23, 9);
      final steps = [
        const PhoneRunStep(
          setId: 'serie',
          kind: RunningStepKind.run,
          completion: RunningStepCompletion.distance,
          meters: 200,
        ),
        const PhoneRunStep(
          setId: 'enfriamiento',
          kind: RunningStepKind.cooldown,
          completion: RunningStepCompletion.manual,
        ),
      ];
      final cubit = PhoneRunCubit(
        executionId: 'pista',
        location: location,
        checkpoints: checkpoints,
        now: () => now,
        feedback: feedback,
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);
      await cubit.open(steps: steps);
      cubit.configure(trackMode: true, voice: PhoneRunVoice.splits);
      await cubit.start();
      for (var second = 0; second <= 52; second++) {
        if (second != 0) now = now.add(const Duration(seconds: 1));
        location.fix(now, second * 4 / 111195);
      }
      expect(feedback.spoken.map((text) => text.split(' ').first), [
        '50',
        '100',
        '150',
      ]);
      expect(feedback.paces.last, isNot('— min/km'));
      expect(cubit.state.step?.id, 'serie');
      cubit.markLap('serie');
      expect(cubit.state.step?.id, 'enfriamiento');
      expect(cubit.laps.single.totals.distanceMeters, greaterThan(200));
      await cubit.pause();
      expect(location.stops, location.starts);

      final restored = PhoneRunCubit(
        executionId: 'pista',
        location: location,
        checkpoints: checkpoints,
        now: () => now,
        feedback: feedback,
      );
      addTearDown(restored.close);
      await restored.open(steps: steps);
      expect(restored.state.phase, PhoneRunPhase.paused);
      expect(restored.state.step?.id, 'enfriamiento');
      expect(restored.state.trackMode, isTrue);
      expect(restored.state.voice, PhoneRunVoice.splits);
      expect(restored.laps.single.stepId, 'serie');
    },
  );

  test(
    'pausar y terminar liberan la ubicación y conservan los datos',
    () async {
      final location = _Location();
      final checkpoints = _Checkpoints();
      var now = DateTime.utc(2026, 11, 22, 9);
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: checkpoints,
        now: () => now,
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);

      await cubit.open();
      expect(cubit.state.phase, PhoneRunPhase.acquiring);
      location.fix(now, 0);
      now = now.add(const Duration(seconds: 1));
      location.fix(now, .00004);
      final firstToken = location.starts.single;
      await cubit.pause();
      expect(location.stops, [firstToken]);
      expect(checkpoints.saved?.recording, isFalse);
      expect(cubit.state.phase, PhoneRunPhase.paused);

      now = now.add(const Duration(minutes: 1));
      await cubit.start();
      location.fix(now, 1);
      now = now.add(const Duration(seconds: 1));
      location.fix(now, 1.00004);
      await cubit.review();
      expect(location.stops, location.starts);
      expect(cubit.state.phase, PhoneRunPhase.review);
      expect(cubit.state.totals.seconds, 2);
      expect(cubit.state.totals.distanceMeters, closeTo(9, 1));
      expect(checkpoints.saved?.recording, isFalse);
    },
  );

  test(
    'una grabación interrumpida se recupera pausada sin reactivar el GPS',
    () async {
      final location = _Location();
      final checkpoints = _Checkpoints()
        ..saved = const PhoneRunCheckpoint(
          PhoneRunTotals(elapsedMilliseconds: 40000, distanceMeters: 90),
          recording: true,
        );
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: checkpoints,
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);

      await cubit.open();
      expect(cubit.state.phase, PhoneRunPhase.paused);
      expect(cubit.state.totals.seconds, 40);
      expect(cubit.state.totals.distanceReliable, isFalse);
      expect(location.starts, isEmpty);
    },
  );

  test(
    'salir mientras se solicita permiso detiene el inicio pendiente',
    () async {
      final permission = Completer<void>();
      final location = _Location()..permission = permission.future;
      final cubit = PhoneRunCubit(
        executionId: 'rodaje',
        location: location,
        checkpoints: _Checkpoints(),
      );
      addTearDown(location.events.close);
      addTearDown(cubit.close);
      final opening = cubit.open();
      await Future<void>.delayed(Duration.zero);
      expect(location.starts, hasLength(1));
      await cubit.pause();
      permission.complete();
      await opening;
      expect(location.stops, location.starts);
      expect(cubit.state.phase, PhoneRunPhase.idle);
    },
  );
}

class _Location implements PhoneRunLocationSource {
  final events = StreamController<PhoneRunLocationEvent>.broadcast(sync: true);
  final starts = <String>[];
  final stops = <String>[];
  Future<void>? permission;

  @override
  Stream<PhoneRunLocationEvent> get locations => events.stream;

  @override
  Future<void> start(String token) async {
    starts.add(token);
    await permission;
  }

  @override
  Future<void> stop(String token) async => stops.add(token);

  void fix(DateTime at, double longitude) => events.add(
    PhoneRunLocationEvent(
      starts.last,
      fix: PhoneRunFix(
        latitude: 0,
        longitude: longitude,
        accuracyMeters: 5,
        at: at,
      ),
    ),
  );
}

class _Cues extends Fake implements WorkoutCueService {
  final events = <WorkoutCue>[];

  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> signal(WorkoutCue cue) async => events.add(cue);
}

class _Feedback implements PhoneRunFeedback {
  final spoken = <String>[];
  final paces = <String>[];

  @override
  Future<void> publish(
    String token, {
    required String phase,
    required String progress,
    required String pace,
    required String distance,
    required int seconds,
  }) async => paces.add(pace);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> silence() async {}

  @override
  Future<void> end(String token) async {}
}

class _Checkpoints implements PhoneRunCheckpoints {
  PhoneRunCheckpoint? saved;

  @override
  Future<PhoneRunCheckpoint?> read(String executionId) async => saved;

  @override
  Future<void> write(String executionId, PhoneRunCheckpoint value) async {
    saved = value;
  }

  @override
  Future<void> clear(String executionId) async => saved = null;
}
