import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/running_step_fields.dart';

void main() {
  for (final width in [240.0, 390.0, 700.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final admin in [false, true]) {
        testWidgets('tramo completo a $width px, texto $scale, admin $admin', (
          t,
        ) async {
          final controllers = [
            TextEditingController(text: '20:00'),
            TextEditingController(text: '05:00'),
            TextEditingController(text: '05:20'),
            TextEditingController(text: '01:00'),
          ];
          addTearDown(() {
            for (final c in controllers) {
              c.dispose();
            }
          });
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SizedBox(
                      width: width,
                      child: RunningStepFields(
                        targetType: WorkoutTargetType.duration,
                        targetController: controllers[0],
                        paceMinController: controllers[1],
                        paceMaxController: controllers[2],
                        recoveryController: controllers[3],
                        recoveryType: RunningRecoveryType.walking,
                        recoveryByDistance: false,
                        adminLabels: admin,
                        onTargetTypeChanged: (_) {},
                        onRecoveryTypeChanged: (_) {},
                        onRecoveryMeasureChanged: (_) {},
                        onEdited: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull);
          for (final element in find.byType(EditableText).evaluate()) {
            final RenderEditable editor = t
                .state<EditableTextState>(find.byWidget(element.widget))
                .renderEditable;
            final painter = TextPainter(
              text: editor.text,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout();
            expect(
              painter.width,
              lessThanOrEqualTo(editor.size.width),
              reason: 'Tiempo completo ${editor.plainText}',
            );
            painter.dispose();
          }
        });
      }
    }
  }
}
