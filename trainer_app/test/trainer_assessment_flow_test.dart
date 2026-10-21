import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_assessment_pages.dart';
import 'package:entrenaop_trainer/trainer_assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/professional_assessment.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

ProfessionalAssessmentVersion sample() => ProfessionalAssessmentVersion(
  id: 'version',
  familyId: 'family',
  version: 2,
  title: 'Control privado',
  tests: const [
    ProfessionalAssessmentTest(
      id: 'run',
      name: 'Recorrido',
      unit: ProfessionalMarkUnit.seconds,
      direction: ProfessionalBetterDirection.lower,
      resolution: 0.01,
      instructions: 'Recorre el trazado y registra la marca.',
      maximumAttempts: 1,
      retryPolicy: ProfessionalRetryPolicy.none,
    ),
  ],
);

class AssessmentFixture extends TrainerAssessmentRepository {
  bool fail = false;
  final saves =
      <
        ({
          String op,
          ProfessionalAssessmentVersion value,
          String? previous,
          int expected,
        })
      >[];
  @override
  Future<List<ProfessionalAssessmentVersion>> list() async => [sample()];
  @override
  Future<ProfessionalAssessmentVersion> get(String id) async => sample();
  @override
  Future<List<ProfessionalAssessmentTest>> catalog() async => [];
  @override
  Future<String> save(
    String op,
    ProfessionalAssessmentVersion value, {
    String? previousId,
    int expectedRevision = 0,
  }) async {
    saves.add((
      op: op,
      value: value,
      previous: previousId,
      expected: expectedRevision,
    ));
    if (fail) throw StateError('Sin conexión');
    return 'saved';
  }

  @override
  Future<void> assign(
    String op,
    String relation,
    String battery,
    DateTime date,
  ) async {}
  @override
  Future<List<ProfessionalAssessmentDelivery>> deliveries(
    String clientId, {
    ProfessionalAssessmentDelivery? before,
  }) async => [];
  @override
  Future<ProfessionalAssessmentDelivery> delivery(String id) async =>
      throw UnimplementedError();
}

Future<void> open(WidgetTester tester, AssessmentFixture repo) async {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/assessments',
        builder: (_, _) => const Scaffold(body: Text('Biblioteca confirmada')),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, _) => TrainerAssessmentEditorPage(
          repository: repo,
          assessmentId: 'version',
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

Future<void> press(WidgetTester tester, String label) async {
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('biblioteca muestra versiones privadas y alcance sin puntos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerAssessmentsPage(
          repository: AssessmentFixture(),
          access: FakeTrainerRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Control privado'), findsOneWidget);
    expect(find.text('1 pruebas · versión 2'), findsOneWidget);
    expect(find.textContaining('no se calculan puntos'), findsOneWidget);
  });
  testWidgets(
    'revisión conserva expected revision y confirma salida sin borrador pendiente',
    (tester) async {
      final repo = AssessmentFixture();
      await open(tester, repo);
      await press(tester, 'Guardar versión');
      expect(repo.saves.single.previous, 'version');
      expect(repo.saves.single.expected, 2);
      expect(repo.saves.single.value.version, 3);
      expect(find.text('Biblioteca confirmada'), findsOneWidget);
    },
  );
  testWidgets('fallo conserva snapshot y operación al reintentar', (
    tester,
  ) async {
    final repo = AssessmentFixture()..fail = true;
    await open(tester, repo);
    await press(tester, 'Guardar versión');
    expect(repo.saves, hasLength(1));
    repo.fail = false;
    await press(tester, 'Reintentar el mismo guardado');
    expect(repo.saves, hasLength(2));
    expect(repo.saves.first, repo.saves.last);
    expect(find.text('Biblioteca confirmada'), findsOneWidget);
  });
}
