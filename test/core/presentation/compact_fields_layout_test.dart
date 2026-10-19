import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';

import '../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final width in [220.0, 280.0, 318.0, 350.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final target in WorkoutTargetType.values) {
        testWidgets(
          'Compacto $target a $width y texto $scale conserva valores',
          (t) async {
            await t.pumpWidget(
              MaterialApp(
                theme: EntrenaTheme.dark,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: SizedBox(
                        width: width,
                        child: StrengthSetFields(
                          targetType: target,
                          targetText: target == WorkoutTargetType.duration
                              ? '90'
                              : '100',
                          restText: '90',
                          loadText: '25.5',
                          rirText: '2.5',
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
            expect(t.takeException(), isNull);
            if (width >= 318 &&
                scale == 1 &&
                target == WorkoutTargetType.repetitions) {
              final decorators = find.byType(InputDecorator);
              expect(
                {
                  for (final e in decorators.evaluate())
                    t.getTopLeft(find.byWidget(e.widget)).dy,
                },
                hasLength(1),
                reason: 'Cuatro valores breves caben en una fila normal',
              );
            }
            for (final element in find.byType(EditableText).evaluate()) {
              final state = t.state<EditableTextState>(
                find.byWidget(element.widget),
              );
              final editor = state.renderEditable;
              final painter = TextPainter(
                text: editor.text,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.linear(scale),
              )..layout();
              expect(
                painter.width,
                lessThanOrEqualTo(editor.size.width),
                reason: '${editor.plainText} completo',
              );
              painter.dispose();
            }
            for (final element in find.byType(RenderObjectWidget).evaluate()) {
              if (element.renderObject case final RenderParagraph paragraph) {
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: 'Etiqueta o valor completo',
                );
              }
            }
          },
        );
      }
    }
  }

  for (final target in [
    WorkoutTargetType.repetitions,
    WorkoutTargetType.duration,
  ]) {
    testWidgets(
      'Compacto muestra valores largos y errores completos en $target',
      (t) async {
        final key = GlobalKey<FormState>();
        await t.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: SizedBox(
                    width: 280,
                    child: Form(
                      key: key,
                      child: StrengthSetFields(
                        targetType: target,
                        targetText: target == WorkoutTargetType.duration
                            ? '3600'
                            : '100000',
                        restText: '3600',
                        loadText: '999.75',
                        rirText: '10',
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
          ),
        );
        for (final e in find.byType(EditableText).evaluate()) {
          final editor = t
              .state<EditableTextState>(find.byWidget(e.widget))
              .renderEditable;
          final painter = TextPainter(
            text: editor.text,
            textDirection: TextDirection.ltr,
            textScaler: const TextScaler.linear(2),
          )..layout();
          expect(painter.width, lessThanOrEqualTo(editor.size.width));
          painter.dispose();
        }
        await t.enterText(find.byType(TextFormField).first, '');
        expect(key.currentState!.validate(), isFalse);
        await t.pumpAndSettle();
        for (final element in find.byType(RenderObjectWidget).evaluate()) {
          if (element.renderObject case final RenderParagraph paragraph) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: 'Error y etiqueta completos',
            );
          }
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
