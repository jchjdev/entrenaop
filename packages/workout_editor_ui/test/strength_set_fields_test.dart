import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';

void main() {
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
