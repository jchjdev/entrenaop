import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/workout_effort_field.dart';

void main() {
  for (final width in [220.0, 390.0, 740.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('campos completos y uniformes a $width px, escala $scale', (
        t,
      ) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: StrengthSetFields(
                      targetType: WorkoutTargetType.repetitions,
                      targetText: '10',
                      restText: '90',
                      loadText: '20',
                      rirText: '2',
                      onTargetChanged: (_) {},
                      onRestChanged: (_) {},
                      onLoadChanged: (_) {},
                      onRirChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final decorators = find.byType(InputDecorator);
        expect(decorators, findsNWidgets(4));
        final sizes = [
          for (final e in decorators.evaluate())
            t.getSize(find.byWidget(e.widget)),
        ];
        expect(sizes.map((s) => s.width).toSet(), hasLength(1));
        expect(
          sizes.map((s) => s.height).reduce((a, b) => a > b ? a : b) -
              sizes.map((s) => s.height).reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(4),
        );
        expect(find.text('01:30'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
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
    await t.tap(find.byType(WorkoutEffortField));
    await t.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(11));
    expect(find.widgetWithText(ChoiceChip, '2.5'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, '0'));
    await t.pumpAndSettle();
    expect(changed, '0');
    await t.tap(find.byType(WorkoutEffortField));
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
