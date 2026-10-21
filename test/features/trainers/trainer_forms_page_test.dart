import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_forms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

TrainerFormAssignment fixture({bool submitted = false, bool active = true}) =>
    TrainerFormAssignment.fromJson({
      'id': 'assignment',
      'form_id': 'form-version',
      'family_id': 'family',
      'version': 1,
      'client_id': 'student',
      'relation_id': 'relation',
      'trainer_name': 'Mi preparador',
      'due_date': '2026-10-22',
      'created_at': '2026-10-21T10:00:00Z',
      'submitted_at': submitted ? '2026-10-21T11:00:00Z' : null,
      'can_respond': !submitted && active,
      'answers': submitted ? {'minutes': 0, 'yes-no': false} : null,
      'content': {
        'title': 'Revisión',
        'questions': [
          {
            'id': 'minutes',
            'position': 0,
            'prompt': 'Minutos',
            'type': 'number',
            'required': true,
            'options': [],
          },
          {
            'id': 'yes-no',
            'position': 1,
            'prompt': '¿Has podido?',
            'type': 'yesNo',
            'required': true,
            'options': [],
          },
        ],
      },
    });

class StudentFormsFixture extends TrainerStudentFormRepository {
  bool fail = false;
  bool failRefreshAfterSubmit = false;
  TrainerFormAssignment row = fixture();
  final submissions = <({String operation, Map<String, Object?> answers})>[];
  @override
  Future<List<TrainerFormAssignment>> mine({
    TrainerFormAssignment? before,
  }) async => [row];
  @override
  Future<TrainerFormAssignment> assignment(String id) async {
    if (failRefreshAfterSubmit && submissions.isNotEmpty) {
      throw StateError('Recarga fallida');
    }
    return row;
  }

  @override
  Future<void> submit(
    String operationId,
    TrainerFormAssignment assignment,
    Map<String, Object?> answers,
  ) async {
    submissions.add((operation: operationId, answers: Map.from(answers)));
    if (fail) throw StateError('Sin conexión');
    row = fixture(submitted: true);
  }
}

Future<void> open(WidgetTester tester, StudentFormsFixture repo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: TrainerStudentFormPage(
        repository: repo,
        assignmentId: 'assignment',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('respuesta confirmada queda cerrada aunque falle la recarga', (
    tester,
  ) async {
    final repo = StudentFormsFixture()..failRefreshAfterSubmit = true;
    await open(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('minutes')), '0');
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Enviar respuestas');
    expect(repo.submissions, hasLength(1));
    expect(
      find.text('Respuesta enviada. Puedes consultarla aquí.'),
      findsOneWidget,
    );
    expect(find.text('Enviar respuestas'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('minutes'))).readOnly,
      isTrue,
    );
  });
  testWidgets('cero y No son respuestas explícitas, no valores ausentes', (
    tester,
  ) async {
    final repo = StudentFormsFixture();
    await open(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('minutes')), '0');
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Enviar respuestas');
    expect(repo.submissions.single.answers, {'minutes': 0.0, 'yes-no': false});
    expect(
      find.text('Respuesta enviada. Puedes consultarla aquí.'),
      findsOneWidget,
    );
    expect(find.text('Enviar respuestas'), findsNothing);
  });
  testWidgets('pregunta obligatoria sin contestar conserva campos y no envía', (
    tester,
  ) async {
    final repo = StudentFormsFixture();
    await open(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('minutes')), '0');
    await tapText(tester, 'Enviar respuestas');
    expect(repo.submissions, isEmpty);
    expect(find.textContaining('Responde la pregunta'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('minutes')))
          .controller!
          .text,
      '0',
    );
  });
  testWidgets('un fallo conserva respuestas y fija el reintento', (
    tester,
  ) async {
    final repo = StudentFormsFixture()..fail = true;
    await open(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('minutes')), '0');
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Enviar respuestas');
    expect(repo.submissions, hasLength(1));
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('minutes'))).readOnly,
      isTrue,
    );
    repo.fail = false;
    await tapText(tester, 'Reintentar el mismo envío');
    expect(repo.submissions, hasLength(2));
    expect(repo.submissions.first.operation, repo.submissions.last.operation);
    expect(repo.submissions.first.answers, repo.submissions.last.answers);
  });
  testWidgets('baja conserva consulta y bloquea respuesta y controles', (
    tester,
  ) async {
    final repo = StudentFormsFixture()..row = fixture(active: false);
    await open(tester, repo);
    expect(find.textContaining('El servicio está inactivo'), findsOneWidget);
    expect(find.text('Enviar respuestas'), findsNothing);
    expect(
      tester
          .widget<DropdownButtonFormField<bool>>(
            find.byType(DropdownButtonFormField<bool>),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('minutes'))).readOnly,
      isTrue,
    );
    expect(repo.submissions, isEmpty);
  });
}
