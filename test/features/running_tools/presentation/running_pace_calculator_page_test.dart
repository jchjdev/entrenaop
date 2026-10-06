import 'package:entrenaop/features/running_tools/presentation/pages/running_pace_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra tiempo y parciales para el ejemplo de 400 metros', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RunningPaceCalculatorPage()),
    );

    expect(find.text('3:40'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('running-total-time')))
          .data,
      '1:28',
    );
    expect(find.text('100 m'), findsWidgets);
    expect(find.text('0:22'), findsWidgets);
    expect(find.text('0:44'), findsOneWidget);
    expect(find.text('1:06'), findsOneWidget);
  });

  testWidgets('mantiene los dos puntos al introducir el ritmo abreviado', (
    tester,
  ) async {
    final pace = find.byKey(const ValueKey('running-pace-input'));
    await tester.pumpWidget(
      const MaterialApp(home: RunningPaceCalculatorPage()),
    );

    await tester.enterText(pace, '415');
    await tester.pump();

    expect(find.text('4:15'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('running-total-time')))
          .data,
      '1:42',
    );
  });
}
