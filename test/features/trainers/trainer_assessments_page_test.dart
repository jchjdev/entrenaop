import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_assessments_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_assessment_codec.dart';

ProfessionalAssessmentDelivery delivery({
  String status = 'in_progress',
  int revision = 1,
  bool active = true,
  Map<String, List<ProfessionalAssessmentAttempt>> answers = const {},
}) => ProfessionalAssessmentCodec.delivery({
  'id': 'delivery',
  'client_id': 'client',
  'trainer_id': 'trainer',
  'relation_id': 'relation',
  'trainer_name': 'Preparador',
  'client_name': 'Alumno',
  'status': status,
  'revision': revision,
  'scheduled_date': '2026-10-21',
  'created_at': '2026-10-20T12:00:00Z',
  'can_start': status == 'planned' && active,
  'can_edit': status == 'in_progress',
  'started_at': status == 'planned' || status == 'withdrawn'
      ? null
      : '2026-10-21T12:00:00Z',
  'completed_at': status == 'completed' ? '2026-10-21T13:00:00Z' : null,
  'answers': ProfessionalAssessmentCodec.encodeAnswers(answers),
  'battery': {
    'id': 'battery',
    'family_id': 'family',
    'version': 1,
    'content': {
      'title': 'Simulacro privado',
      'tests': [
        {
          'id': 'run',
          'source': 'custom',
          'name': 'Recorrido',
          'unit': 'seconds',
          'direction': 'lower',
          'resolution': 0.01,
          'instructions': 'Realiza el recorrido indicado y registra la marca.',
          'max_attempts': 1,
          'retry_policy': 'none',
          'protocol_fingerprint': 'hash',
        },
      ],
    },
  },
});

class AssessmentFixture extends ProfessionalAssessmentStudentRepository {
  ProfessionalAssessmentDelivery row = buildDelivery();
  bool fail = false;
  final writes =
      <
        ({
          String operation,
          int revision,
          Map<String, List<ProfessionalAssessmentAttempt>> answers,
          bool finish,
        })
      >[];
  final starts = <String>[];
  @override
  Future<List<ProfessionalAssessmentDelivery>> mine({
    ProfessionalAssessmentDelivery? before,
  }) async => [row];
  @override
  Future<ProfessionalAssessmentDelivery> delivery(String id) async => row;
  @override
  Future<ProfessionalAssessmentDelivery> start(
    String op,
    ProfessionalAssessmentDelivery previous,
  ) async {
    starts.add(op);
    if (fail) throw StateError('Sin conexión');
    row = buildDelivery(status: 'in_progress', revision: previous.revision + 1);
    return row;
  }

  @override
  Future<ProfessionalAssessmentDelivery> save(
    String op,
    ProfessionalAssessmentDelivery previous,
    Map<String, List<ProfessionalAssessmentAttempt>> answers, {
    required bool finish,
  }) async {
    writes.add((
      operation: op,
      revision: previous.revision,
      answers: answers,
      finish: finish,
    ));
    if (fail) throw StateError('Sin conexión');
    row = buildDelivery(
      status: finish ? 'completed' : 'in_progress',
      revision: previous.revision + 1,
      answers: answers,
    );
    return row;
  }
}

ProfessionalAssessmentDelivery buildDelivery({
  String status = 'in_progress',
  int revision = 1,
  Map<String, List<ProfessionalAssessmentAttempt>> answers = const {},
}) => delivery(status: status, revision: revision, answers: answers);
Future<void> open(WidgetTester tester, AssessmentFixture repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: TrainerStudentAssessmentPage(
        repository: repository,
        deliveryId: 'delivery',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'recarga confirmada sustituye captura local aunque revisión no cambie',
    (tester) async {
      final repo = AssessmentFixture();
      await open(tester, repo);
      await tester.enterText(find.byType(TextField), '12,25');
      await tester.tap(find.byTooltip('Consultar última revisión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conservar borrador'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '12,25',
      );
      await tester.tap(find.byTooltip('Consultar última revisión'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Consultar última revisión'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(repo.writes, isEmpty);
    },
  );
  testWidgets(
    'no inicia hasta confirmar protocolo y conserva operación al reintentar',
    (tester) async {
      final repo = AssessmentFixture()
        ..row = delivery(status: 'planned', revision: 0)
        ..fail = true;
      await open(tester, repo);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Comenzar pruebas'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await press(tester, 'Comenzar pruebas');
      expect(repo.starts, hasLength(1));
      repo.fail = false;
      await press(tester, 'Reintentar la misma operación');
      expect(repo.starts, hasLength(2));
      expect(repo.starts.first, repo.starts.last);
    },
  );
  testWidgets(
    'marca cero cierra con versión esperada y consulta queda bloqueada',
    (tester) async {
      final repo = AssessmentFixture();
      await open(tester, repo);
      await tester.enterText(find.byType(TextField), '0');
      await press(tester, 'Finalizar pruebas');
      expect(repo.writes.single.answers['run']!.single.value, 0);
      expect(repo.writes.single.revision, 1);
      expect(repo.writes.single.finish, isTrue);
      expect(find.text('Finalizar pruebas'), findsNothing);
    },
  );
  testWidgets('error conserva respuesta y reintenta el mismo payload', (
    tester,
  ) async {
    final repo = AssessmentFixture()..fail = true;
    await open(tester, repo);
    await tester.enterText(find.byType(TextField), '12,25');
    await press(tester, 'Finalizar pruebas');
    expect(repo.writes, hasLength(1));
    repo.fail = false;
    await press(tester, 'Reintentar la misma operación');
    expect(repo.writes, hasLength(2));
    expect(repo.writes.first, repo.writes.last);
  });
  testWidgets('pendiente retirada no permite inicio ni crea captura vacía', (
    tester,
  ) async {
    final repo = AssessmentFixture()..row = delivery(status: 'withdrawn');
    await open(tester, repo);
    expect(find.text('Comenzar pruebas'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(repo.starts, isEmpty);
  });
}
