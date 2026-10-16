import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';

void main() {
  testWidgets('el selector no desborda a 185 px con texto ampliado', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 185,
              child: StrengthSetFields(
                targetType: WorkoutTargetType.repetitions,
                targetText: '10',
                restText: '60',
                loadText: '',
                rirText: '',
                rirLabel: 'RIR (opcional)',
                showTarget: false,
                showRest: false,
                showLoad: false,
                onTargetChanged: (_) {},
                onRestChanged: (_) {},
                onLoadChanged: (_) {},
                onRirChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sin registrar'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('RIR antiguo intacto hasta elección entera o desconocido', (
    t,
  ) async {
    String? changed;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StrengthSetFields(
            targetType: WorkoutTargetType.repetitions,
            targetText: '10',
            restText: '60',
            loadText: '',
            rirText: '2.5',
            onTargetChanged: (_) {},
            onRestChanged: (_) {},
            onLoadChanged: (_) {},
            onRirChanged: (v) => changed = v,
          ),
        ),
      ),
    );
    expect(find.text('2.5'), findsOneWidget);
    expect(changed, isNull);
    await t.tap(find.text('RIR'));
    await t.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(11));
    expect(find.widgetWithText(ChoiceChip, '2.5'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, '0'));
    await t.pumpAndSettle();
    expect(changed, '0');
    await t.tap(find.text('RIR'));
    await t.pumpAndSettle();
    await t.tap(find.text('No lo sé · Sin registrar'));
    await t.pumpAndSettle();
    expect(changed, '');
  });
  testWidgets(
    'muestra reloj y entrega segundos sin cambiar el contrato del editor',
    (tester) async {
      final form = GlobalKey<FormState>();
      String? target, rest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: StrengthSetFields(
                targetType: WorkoutTargetType.duration,
                targetText: '30',
                restText: '90',
                loadText: '',
                rirText: '',
                onTargetChanged: (value) => target = value,
                onRestChanged: (value) => rest = value,
                onLoadChanged: (_) {},
                onRirChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('RIR'), findsNothing);
      final time = find.widgetWithText(TextFormField, 'Tiempo');
      final pause = find.widgetWithText(TextFormField, 'Descanso');
      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);
      await tester.enterText(time, '130');
      await tester.enterText(pause, '00:00');
      expect(target, '90');
      expect(rest, '0');
      expect(form.currentState!.validate(), isTrue);
      await tester.enterText(time, '00:99');
      expect(form.currentState!.validate(), isFalse);
    },
  );
}
