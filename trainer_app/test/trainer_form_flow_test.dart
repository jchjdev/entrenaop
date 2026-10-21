import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_form_pages.dart';
import 'package:entrenaop_trainer/trainer_form_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

TrainerFollowupFormVersion sample() => TrainerFollowupFormVersion(
  formId: 'family',
  versionId: 'version-1',
  revision: 1,
  title: 'Revisión privada',
  questions: [
    TrainerFollowupQuestion(
      id: 'stable-question',
      position: 0,
      prompt: 'Comentario',
      type: TrainerFollowupQuestionType.shortText,
    ),
  ],
);

class FormFixture extends TrainerFormRepository {
  bool fail = false;
  List<TrainerFollowupFormVersion> rows = [sample()];
  final saves =
      <
        ({String operation, TrainerFollowupFormVersion form, String? previous})
      >[];
  @override
  Future<List<TrainerFollowupFormVersion>> list() async => rows;
  @override
  Future<TrainerFollowupFormVersion> get(String id) async => rows.single;
  @override
  Future<String> save(
    String operationId,
    TrainerFollowupFormVersion form, {
    String? previousId,
  }) async {
    saves.add((operation: operationId, form: form, previous: previousId));
    if (fail) throw StateError('Conexión interrumpida');
    return 'saved';
  }

  @override
  Future<void> assign(
    String operationId, {
    required String relationId,
    required String formId,
    required DateTime dueDate,
  }) async {}
  @override
  Future<List<TrainerFormAssignment>> assignments(
    String clientId, {
    TrainerFormAssignment? before,
  }) async => [];
  @override
  Future<TrainerFormAssignment> assignment(String id) async =>
      throw UnimplementedError();
}

Future<void> openEditor(
  WidgetTester tester,
  FormFixture repo, {
  bool revision = false,
}) async {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Biblioteca')),
      ),
      GoRoute(
        path: '/forms',
        builder: (_, _) => const Scaffold(body: Text('Biblioteca')),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, _) => TrainerFormEditorPage(
          repository: repo,
          formId: revision ? 'version-1' : null,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
}

void main() {
  testWidgets('biblioteca profesional muestra formulario y versión', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerFormsPage(
          repository: FormFixture(),
          access: FakeTrainerRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revisión privada'), findsOneWidget);
    expect(find.text('Versión 1 · 1 preguntas'), findsOneWidget);
  });
  testWidgets(
    'revisión conserva identidad de pregunta y no sustituye versión anterior',
    (tester) async {
      final repo = FormFixture();
      await openEditor(tester, repo, revision: true);
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Revisión nueva',
      );
      await tapText(tester, 'Guardar versión');
      await tester.pumpAndSettle();
      expect(repo.saves.single.previous, 'version-1');
      expect(repo.saves.single.form.questions.single.id, 'stable-question');
      expect(repo.rows.single.title, 'Revisión privada');
    },
  );
  testWidgets('error conserva borrador y reintenta misma orden y contenido', (
    tester,
  ) async {
    final repo = FormFixture()..fail = true;
    await openEditor(tester, repo);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Revisión semanal',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Pregunta'),
      '¿Qué tal?',
    );
    await tapText(tester, 'Guardar versión');
    await tester.pumpAndSettle();
    expect(find.text('Revisión semanal'), findsOneWidget);
    expect(repo.saves, hasLength(1));
    repo.fail = false;
    await tapText(tester, 'Reintentar el mismo guardado');
    await tester.pumpAndSettle();
    expect(repo.saves, hasLength(2));
    expect(repo.saves.first.operation, repo.saves.last.operation);
    expect(identical(repo.saves.first.form, repo.saves.last.form), isTrue);
  });
  testWidgets(
    'validación local conserva campos y no envía formulario incompleto',
    (tester) async {
      final repo = FormFixture();
      await openEditor(tester, repo);
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Sin pregunta',
      );
      await tapText(tester, 'Guardar versión');
      await tester.pumpAndSettle();
      expect(repo.saves, isEmpty);
      expect(find.text('Sin pregunta'), findsOneWidget);
    },
  );
}
