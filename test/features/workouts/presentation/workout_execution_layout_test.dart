import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_execution_layout.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la foto aprovecha el alto extra sin alejar reloj y acción', (
    tester,
  ) async {
    await _mount(tester, height: 844);
    final photo = tester.getSize(find.byType(Image)).height;
    final timer = tester.getRect(find.byType(WorkoutSetCountdown));
    final finish = tester.getRect(find.byKey(const ValueKey('finish')));
    expect(photo, greaterThan(160));
    expect(finish.top - timer.bottom, lessThanOrEqualTo(24));

    tester.view.physicalSize = const Size(390, 944);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Image)).height - photo, closeTo(100, 1));
    expect(find.byKey(const ValueKey('finish')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'texto doble y título largo desplazan contenido sin tapar acción',
    (tester) async {
      await _mount(tester, width: 320, height: 568, scale: 2);
      expect(
        find.byKey(const ValueKey('finish')).hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Iniciar temporizador'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar temporizador').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el teclado permite registrar sin desbordar la foto flexible', (
    tester,
  ) async {
    await _mount(tester, resultField: true);
    final field = find.byType(TextFormField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '8');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    expect(find.text('8'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  bool resultField = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Entrenamiento')),
        body: SafeArea(
          child: WorkoutExecutionFrame(
            fillViewport: true,
            actions: FilledButton(
              key: const ValueKey('finish'),
              onPressed: () {},
              child: const Text('Terminar serie'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WorkoutExerciseHeader(
                    name: 'Dominada con agarre neutro y pausa isométrica',
                    position: 'Principal · Serie 1',
                    imageUrl: 'https://example.invalid/exercise.jpg',
                    expandImage: true,
                    onTechnique: () {},
                  ),
                ),
                const SizedBox(height: 12),
                if (resultField)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Repeticiones',
                    ),
                  )
                else
                  WorkoutSetCountdown(
                    targetSeconds: 20,
                    compact: true,
                    onElapsedChanged: (_) {},
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
