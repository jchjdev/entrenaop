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

    expect(find.text('03:40'), findsWidgets);
    expect(find.byKey(const ValueKey('running-distance-unit')), findsNothing);
    expect(
      find.byKey(const ValueKey('running-calculation-mode')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('running-target-time-input')),
      findsNothing,
    );
    expect(find.text('Tiempo de la serie'), findsOneWidget);
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

    expect(find.text('04:15'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('running-total-time')))
          .data,
      '1:42',
    );
  });

  testWidgets(
    'Series conserva solo metros enteros y el límite original de 2000 m',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      final input = find.byKey(const ValueKey('running-distance-input'));
      expect(find.text('Entre 1 y 2000 m'), findsOneWidget);
      for (final value in ['', '0', '2001', '9999']) {
        await tester.enterText(input, value);
        await tester.pump();
        expect(find.byKey(const ValueKey('running-total-time')), findsNothing);
        expect(find.text('Introduce una distancia válida'), findsOneWidget);
      }
      await tester.enterText(input, '2000');
      await tester.pump();
      expect(totalText(tester), '7:20');
      expect(find.text('2000 m a 3:40/km'), findsOneWidget);
      expect(find.text('2000 m · meta'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('running-calculation-mode')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('running-distance-unit')), findsNothing);
    },
  );

  for (final (label, distance, total) in [
    ('5 km', '5', '25:00'),
    ('10 km', '10', '50:00'),
    ('Media maratón', '21,0975', '1:45:29'),
    ('Maratón', '42,195', '3:30:59'),
  ]) {
    testWidgets('elige $label con distancia exacta y pasos por kilómetro', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tester.enterText(
        find.byKey(const ValueKey('running-pace-input')),
        '500',
      );
      await tapVisible(tester, find.widgetWithText(ChoiceChip, label));
      expect(distanceText(tester), distance);
      expect(totalText(tester), total);
      expect(find.text('Automático · cada 1 km'), findsOneWidget);
      if (label == 'Media maratón') {
        expect(find.text('21,0975 km · meta'), findsOneWidget);
        expect(find.text('0:29 / 97,5 m'), findsOneWidget);
      }
      if (label == 'Maratón') {
        await tapVisible(tester, find.widgetWithText(ChoiceChip, '5 km').last);
        expect(find.text('Cada 5 km'), findsOneWidget);
        expect(find.text('10:59 / 2,195 km'), findsOneWidget);
        expect(totalText(tester), total);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'permite distancia libre en km con coma o punto y convierte a metros',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      final input = find.byKey(const ValueKey('running-distance-input'));
      for (final value in ['7,5', '7.5']) {
        await tester.enterText(input, value);
        await tester.pump();
        expect(totalText(tester), '27:30');
        expect(find.text('7,5 km · meta'), findsOneWidget);
        expect(find.text('1:50 / 500 m'), findsOneWidget);
      }
      await tapVisible(
        tester,
        find.byKey(const ValueKey('running-distance-unit')),
      );
      await tapVisible(tester, find.text('m').last);
      expect(distanceText(tester), '7500');
      expect(totalText(tester), '27:30');
      await tester.enterText(
        find.byKey(const ValueKey('running-pace-input')),
        '500',
      );
      await tester.pump();
      expect(totalText(tester), '37:30');
      await tapVisible(tester, find.text('Series'));
      expect(distanceText(tester), '400');
      expect(totalText(tester), '1:28');
      expect(find.byKey(const ValueKey('running-distance-unit')), findsNothing);
      await tapVisible(tester, find.text('Carreras'));
      expect(distanceText(tester), '7500');
      expect(totalText(tester), '37:30');
    },
  );

  testWidgets(
    'conserva los parciales por grupo y descarta los incompatibles al acortar la serie',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '200 m').last);
      expect(find.text('Cada 200 m'), findsOneWidget);
      await tapVisible(tester, find.text('Carreras'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '10 km'));
      expect(find.text('Automático · cada 1 km'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '5 km').last);
      await tapVisible(tester, find.text('Series'));
      expect(find.text('Cada 200 m'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '100 m').first);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '400 m').first);
      expect(find.text('Automático · cada 100 m'), findsOneWidget);
      expect(totalText(tester), '1:28');
    },
  );

  testWidgets(
    'rechaza distancia vacía, cero y superior al límite y permite recuperarse',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('running-distance-unit')),
      );
      await tapVisible(tester, find.text('m').last);
      final input = find.byKey(const ValueKey('running-distance-input'));
      for (final value in ['', '0', '100001']) {
        await tester.enterText(input, value);
        await tester.pump();
        expect(find.byKey(const ValueKey('running-total-time')), findsNothing);
        expect(find.text('Introduce una distancia válida'), findsOneWidget);
      }
      await tester.enterText(input, '21097,5');
      await tester.pump();
      expect(find.text('Introduce una distancia válida'), findsNothing);
      expect(find.text('21,0975 km · meta'), findsOneWidget);
    },
  );

  for (final (width, scale) in [(320.0, 2.0), (390.0, 1.0), (1000.0, 1.0)]) {
    testWidgets('maratón usable sin desbordar a $width px con texto $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RunningPaceCalculatorPage(),
        ),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Maratón'));
      await tester.ensureVisible(
        find.byKey(const ValueKey('running-total-time')),
      );
      await tester.pumpAndSettle();
      expect(totalText(tester), '2:34:43');
      if (width == 320) {
        expect(find.text('Tramo: 3:40 / 1 km'), findsWidgets);
        expect(find.text('Acumulado: 2:34:43'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Series'));
      await tester.ensureVisible(
        find.byKey(const ValueKey('running-total-time')),
      );
      await tester.pumpAndSettle();
      expect(totalText(tester), '1:28');
      expect(
        find.byKey(const ValueKey('running-calculation-mode')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('running-distance-unit')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '10 km en 45 minutos muestra solo tiempo de entrada y ritmo de salida',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '10 km'));
      await selectCalculation(tester, 'Calcular ritmo');
      expect(find.byKey(const ValueKey('running-pace-input')), findsNothing);
      expect(find.byKey(const ValueKey('running-required-pace')), findsNothing);
      expect(
        find.text('Introduce un tiempo válido mayor que cero'),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '4500',
      );
      await tester.pump();
      expect(requiredPace(tester), '4:30/km');
      expect(find.text('Tiempo total'), findsNothing);
      expect(find.text('10 km en 45:00'), findsOneWidget);
      expect(find.text('45:00'), findsWidgets);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '5 km').last);
      expect(requiredPace(tester), '4:30/km');
      expect(find.text('22:30 / 5 km'), findsWidgets);
    },
  );

  testWidgets(
    'Carreras permite calcular ritmo para una distancia libre de 2 km',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tester.enterText(
        find.byKey(const ValueKey('running-distance-input')),
        '2',
      );
      await tester.pump();
      await selectCalculation(tester, 'Calcular ritmo');
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '630',
      );
      await tester.pump();
      expect(requiredPace(tester), '3:15/km');
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '6:20',
      );
      await tester.pump();
      expect(requiredPace(tester), '3:10/km');
      expect(find.text('1:16 / 400 m'), findsWidgets);
      expect(find.text('2 km en 6:20'), findsOneWidget);
      expect(find.text('6:20'), findsOneWidget);
    },
  );

  testWidgets('admite horas y avisa del ritmo aproximado sin alterar la meta', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RunningPaceCalculatorPage()),
    );
    await tapVisible(tester, find.text('Carreras'));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Maratón'));
    await selectCalculation(tester, 'Calcular ritmo');
    await tester.enterText(
      find.byKey(const ValueKey('running-target-time-input')),
      '33000',
    );
    await tester.pump();
    expect(requiredPace(tester), '≈ 4:59/km');
    expect(find.text('42,195 km en 3:30:00'), findsOneWidget);
    expect(find.text('3:30:00'), findsOneWidget);
    expect(
      find.text(
        'Ritmo aproximado al segundo. Los parciales conservan tu tiempo objetivo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'cambiar el modo conserva ambos borradores y solo valida el campo activo',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tester.enterText(
        find.byKey(const ValueKey('running-distance-input')),
        '0,4',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('running-pace-input')),
        '0',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('running-total-time')), findsNothing);
      await selectCalculation(tester, 'Calcular ritmo');
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '120',
      );
      await tester.pump();
      expect(requiredPace(tester), '3:20/km');
      await selectCalculation(tester, 'Calcular tiempo');
      expect(
        find.byKey(const ValueKey('running-target-time-input')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('running-total-time')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('running-pace-input')),
        '400',
      );
      await tester.pump();
      expect(totalText(tester), '1:36');
      await selectCalculation(tester, 'Calcular ritmo');
      expect(requiredPace(tester), '3:20/km');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('running-target-time-input')),
            )
            .controller!
            .text,
        '01:20',
      );
    },
  );

  testWidgets(
    'tiempo vacío o inválido no calcula y permite corregir sin afectar el otro modo',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tester.enterText(
        find.byKey(const ValueKey('running-distance-input')),
        '0,4',
      );
      await tester.pump();
      await selectCalculation(tester, 'Calcular ritmo');
      final input = find.byKey(const ValueKey('running-target-time-input'));
      for (final value in ['0', '6:99', '']) {
        await tester.enterText(input, value);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('running-required-pace')),
          findsNothing,
        );
        expect(
          find.text('Introduce un tiempo válido mayor que cero'),
          value.isEmpty ? findsNothing : findsOneWidget,
        );
      }
      await selectCalculation(tester, 'Calcular tiempo');
      expect(totalText(tester), '1:28');
    },
  );

  testWidgets(
    'al cambiar distancia y unidad se recalcula el ritmo conservando el objetivo',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RunningPaceCalculatorPage()),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '10 km'));
      await selectCalculation(tester, 'Calcular ritmo');
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '4500',
      );
      await tester.pump();
      await tapVisible(tester, find.widgetWithText(ChoiceChip, '5 km').first);
      expect(requiredPace(tester), '9:00/km');
      await tapVisible(tester, find.text('Series'));
      expect(distanceText(tester), '400');
      expect(totalText(tester), '1:28');
      expect(
        find.byKey(const ValueKey('running-target-time-input')),
        findsNothing,
      );
      await tapVisible(tester, find.text('Carreras'));
      expect(distanceText(tester), '5');
      expect(requiredPace(tester), '9:00/km');
    },
  );

  for (final (width, scale) in [(320.0, 2.0), (390.0, 1.0), (1000.0, 1.0)]) {
    testWidgets('modo inverso sin desbordar a $width px y texto $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RunningPaceCalculatorPage(),
        ),
      );
      await tapVisible(tester, find.text('Carreras'));
      await tester.enterText(
        find.byKey(const ValueKey('running-distance-input')),
        '0,4',
      );
      await tester.pump();
      await selectCalculation(tester, 'Calcular ritmo');
      await tester.enterText(
        find.byKey(const ValueKey('running-target-time-input')),
        '120',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('running-required-pace')),
      );
      await tester.pumpAndSettle();
      expect(requiredPace(tester), '3:20/km');
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String? distanceText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('running-distance-input')))
    .controller!
    .text;

String? totalText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('running-total-time'))).data;

Future<void> selectCalculation(WidgetTester tester, String label) async {
  await tapVisible(
    tester,
    find.byKey(const ValueKey('running-calculation-mode')),
  );
  await tapVisible(tester, find.text(label).last);
}

String? requiredPace(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('running-required-pace')))
    .data;
