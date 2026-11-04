import 'package:entrenaop/features/dashboard/presentation/pages/tool_clock_page.dart';
import 'package:entrenaop/features/workouts/data/services/shared_preferences_workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const screen = MethodChannel('es.entrenaop/clock_screen');
  late Duration now;
  late List<bool> screenChanges;
  late List<WorkoutCue> cues;

  setUp(() {
    now = Duration.zero;
    screenChanges = [];
    cues = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screen, (call) async {
          expect(call.method, 'setEnabled');
          screenChanges.add(call.arguments as bool);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(screen, null);
  });

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_cues.sound_enabled': false,
    });
    final service = SharedPreferencesWorkoutCueService(
      await SharedPreferences.getInstance(),
      haptic: (cue) async => cues.add(cue),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ToolClockPage(cueService: service, clock: () => now),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }

  Future<void> advance(WidgetTester tester, int seconds) async {
    now += Duration(seconds: seconds);
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final rounds in [4, 10]) {
    testWidgets(
      'encadena $rounds rondas editadas y termina con el último trabajo',
      (tester) async {
        await open(tester);
        await tap(tester, 'Intervalos');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Rondas'),
          '$rounds',
        );
        await tap(tester, 'Iniciar');

        for (var round = 1; round <= rounds; round++) {
          expect(
            find.text('Trabajo · ronda $round de $rounds'),
            findsOneWidget,
          );
          await advance(tester, 10);
          await advance(tester, 10);
          if (round == rounds) break;
          expect(
            find.text('Descanso · ronda $round de $rounds'),
            findsOneWidget,
          );
          await advance(tester, 10);
        }
        expect(find.text('Terminado'), findsOneWidget);
        expect(screenChanges, [true, false]);
        expect(
          cues.where((cue) => cue == WorkoutCue.workStarted),
          hasLength(rounds),
        );
        expect(cues.last, WorkoutCue.workFinished);
        expect(
          cues.where((cue) => cue == WorkoutCue.halfway),
          hasLength(rounds),
        );
      },
    );
  }

  testWidgets(
    'el temporizador rápido mantiene el restante al pausar y reanudar',
    (tester) async {
      await open(tester);
      await tap(tester, 'Temporizador');
      await tap(tester, '30 s');
      await tap(tester, 'Iniciar');
      await advance(tester, 12);
      await tap(tester, 'Pausar');
      await advance(tester, 60);
      expect(find.text('00:18'), findsOneWidget);

      await tap(tester, 'Reanudar');
      await advance(tester, 3);
      expect(cues, [WorkoutCue.halfway]);
      await advance(tester, 15);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Terminado'), findsOneWidget);
      expect(screenChanges, [true, false, true, false]);
      expect(cues, [WorkoutCue.halfway, WorkoutCue.workFinished]);
    },
  );

  testWidgets(
    'el cronómetro pausa al ocultarse y libera la pantalla al salir',
    (tester) async {
      await open(tester);
      await tap(tester, 'Iniciar');
      await advance(tester, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await advance(tester, 25);
      expect(find.text('00:03.000'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);
      expect(screenChanges, [true, false]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tap(tester, 'Reanudar');
      await advance(tester, 2);
      expect(find.text('00:05.000'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(screenChanges, [true, false, true, false]);
    },
  );

  testWidgets(
    'mide vueltas con milésimas y mantiene controles al girar el iPhone 12',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await open(tester);
      await tap(tester, 'Iniciar');
      now = const Duration(milliseconds: 1234);
      await tap(tester, 'Vuelta');

      const landscapePadding = FakeViewPadding(left: 47, right: 47, bottom: 21);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = landscapePadding;
      tester.view.viewPadding = landscapePadding;
      now = const Duration(milliseconds: 3421);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('00:03.421').hitTestable(), findsOneWidget);
      expect(find.text('Vuelta 1').hitTestable(), findsOneWidget);
      expect(find.text('Pausar').hitTestable(), findsOneWidget);
      final lap = find.text('Vuelta').hitTestable();
      expect(lap, findsOneWidget);
      now = const Duration(milliseconds: 3456);
      await tester.tap(lap);
      await tester.pump();
      expect(find.text('00:02.222'), findsOneWidget);
      expect(find.text('Vuelta 2'), findsOneWidget);
      await tap(tester, 'Pausar');
      expect(find.text('00:03.456').hitTestable(), findsOneWidget);
      await tap(tester, 'Reiniciar');
      expect(find.text('Vuelta 1'), findsNothing);
      expect(find.text('00:00.000').hitTestable(), findsOneWidget);

      await tap(tester, 'Intervalos');
      expect(find.text('00:20').hitTestable(), findsOneWidget);
      expect(find.text('Iniciar').hitTestable(), findsOneWidget);
      await tap(tester, 'Temporizador');
      expect(find.text('01:00').hitTestable(), findsOneWidget);
      expect(find.text('Iniciar').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
