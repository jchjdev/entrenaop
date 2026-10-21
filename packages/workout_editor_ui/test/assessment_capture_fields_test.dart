import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_editor_ui/assessment_capture_fields.dart';

final battery = ProfessionalAssessmentVersion(
  id: 'v',
  familyId: 'f',
  version: 1,
  title: 'Prueba',
  tests: const [
    ProfessionalAssessmentTest(
      id: 'run',
      name: 'Control',
      unit: ProfessionalMarkUnit.seconds,
      direction: ProfessionalBetterDirection.lower,
      resolution: 0.01,
      instructions: 'Registra el tiempo del recorrido indicado.',
      maximumAttempts: 2,
      retryPolicy: ProfessionalRetryPolicy.invalidOnly,
    ),
  ],
);
void main() {
  testWidgets('cero se registra como válido y nulo se declara sin marca', (
    tester,
  ) async {
    var answers = <String, List<ProfessionalAssessmentAttempt>>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssessmentCaptureFields(
              form: battery,
              onChanged: (a) => answers = a,
            ),
          ),
        ),
      ),
    );
    expect(answers, isEmpty);
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    expect(answers['run']!.single.valid, isTrue);
    expect(answers['run']!.single.value, 0);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nulo: sin marca válida').last);
    await tester.pumpAndSettle();
    expect(answers['run']!.single.valid, isFalse);
    expect(answers['run']!.single.value, isNull);
    await tester.tap(find.text('Añadir intento'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).last, '10,25');
    await tester.pumpAndSettle();
    expect(answers['run']!.last.value, 10.25);
    expect(
      ProfessionalAssessmentValidator.answers(
        battery,
        answers,
        complete: true,
      )['run'],
      hasLength(2),
    );
  });
  testWidgets('marcar válido impide repetir con política solo tras nulo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssessmentCaptureFields(form: battery, onChanged: (_) {}),
        ),
      ),
    );
    final add = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Añadir intento'),
    );
    expect(add.onPressed, isNull);
  });
  testWidgets('consulta cerrada bloquea cambios sin transformar nulo en cero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssessmentCaptureFields(
            form: battery,
            readOnly: true,
            initialAnswers: const {
              'run': [ProfessionalAssessmentAttempt(valid: false)],
            },
            onChanged: (_) => fail('No debe modificar consulta'),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<DropdownButtonFormField<bool>>(
            find.byType(DropdownButtonFormField<bool>),
          )
          .onChanged,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Añadir intento'), findsNothing);
  });
}
