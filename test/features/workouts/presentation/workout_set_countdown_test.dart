import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cuenta, permite pausar y entrega los segundos realizados', (
    tester,
  ) async {
    var elapsed = -1;
    var now = Duration.zero;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: WorkoutSetCountdown(
            targetSeconds: 3,
            onElapsedChanged: (value) => elapsed = value,
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

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);

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
  });
}
