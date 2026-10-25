import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_opposition_goal.dart';
import 'package:entrenaop_trainer/trainer_client_goals.dart';
import 'package:entrenaop_trainer/trainer_client_goals_repository.dart';

import 'trainer_exercise_repository_test.dart' show owner;
import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;

ProfessionalAssessmentTest protocol({
  String id = 'protocol',
  ProfessionalMarkUnit unit = ProfessionalMarkUnit.seconds,
  ProfessionalBetterDirection direction = ProfessionalBetterDirection.lower,
}) => ProfessionalAssessmentTest(
  id: id,
  name: 'Carrera $id',
  unit: unit,
  direction: direction,
  resolution: unit == ProfessionalMarkUnit.repetitions ? 1 : .01,
  instructions: 'Recorrer la distancia fijada sin salir de la pista.',
  maximumAttempts: 1,
  retryPolicy: ProfessionalRetryPolicy.none,
  protocolId: id,
  protocolVersion: 1,
  protocolFingerprint: 'fingerprint-$id',
);

class FakeGoals extends TrainerClientGoalsRepository {
  ProfessionalOppositionGoal goal = ProfessionalOppositionGoal(
    revision: 0,
    title: '',
  );
  final writes =
      <
        ({
          String operation,
          int revision,
          ProfessionalOppositionGoalDraft draft,
        })
      >[];
  Object? stableScope;
  @override
  Object get scope => stableScope ?? super.scope;
  bool fail = false;
  @override
  Future<ProfessionalOppositionGoal> get(String clientId) async => goal;
  @override
  Future<List<ProfessionalAssessmentTest>> protocols() async => [protocol()];
  @override
  Future<int> save(
    String operationId,
    String clientId,
    int expectedRevision,
    ProfessionalOppositionGoalDraft draft,
  ) async {
    writes.add((
      operation: operationId,
      revision: expectedRevision,
      draft: draft,
    ));
    if (fail) throw TimeoutException('respuesta perdida');
    goal = ProfessionalOppositionGoal(
      revision: expectedRevision + 1,
      title: draft.title,
      targetDate: draft.targetDate,
      targets: draft.targets,
    );
    return expectedRevision + 1;
  }
}

Widget app(FakeGoals repository, {bool canEdit = true}) => MaterialApp(
  theme: EntrenaTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(
      child: TrainerClientGoalsPanel(
        repository: repository,
        clientId: 'student',
        canEdit: canEdit,
      ),
    ),
  ),
);

void main() {
  test('tiempo y resolución reutilizan el contrato de pruebas', () {
    final p = protocol();
    final parsed = ProfessionalAssessmentValidator.parseMark('1:30,12', p);
    final draft = ProfessionalOppositionGoalDraft(
      title: '  Policía Nacional  ',
      targetDate: DateTime(2027, 2, 12),
      targets: [ProfessionalOppositionGoalTarget(protocol: p, value: parsed)],
    ).normalized();
    expect(draft.title, 'Policía Nacional');
    expect(draft.toJson()['target_date'], '2027-02-12');
    expect((draft.toJson()['targets'] as List).single, {
      'protocol_id': 'protocol',
      'value': 90.12,
    });
    expect(
      () => ProfessionalAssessmentValidator.parseMark('90.123', p),
      throwsFormatException,
    );
    expect(
      () => ProfessionalOppositionGoalDraft(
        title: 'Meta',
        targets: [
          ProfessionalOppositionGoalTarget(protocol: p, value: 90.12),
          ProfessionalOppositionGoalTarget(protocol: p, value: 89),
        ],
      ).normalized(),
      throwsFormatException,
    );
  });
  test('actualidad y evolución conservan dirección, cero y ausencia', () {
    final lower = protocol();
    final higher = protocol(
      id: 'reps',
      unit: ProfessionalMarkUnit.repetitions,
      direction: ProfessionalBetterDirection.higher,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: lower,
        value: 90,
        best: 80,
        latest: 92,
        previous: 94,
        hasLatestEvidence: true,
      ).reached,
      false,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: lower,
        value: 90,
        latest: 89.99,
        hasLatestEvidence: true,
      ).reached,
      true,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: lower,
        value: 90,
        latest: 92,
        previous: 94,
        hasLatestEvidence: true,
      ).favorableChange,
      2,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: higher,
        value: 10,
        latest: 0,
        previous: 2,
        hasLatestEvidence: true,
      ).favorableChange,
      -2,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: higher,
        value: 0,
        latest: 0,
        hasLatestEvidence: true,
      ).reached,
      true,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: lower,
        value: 90,
        best: 80,
      ).reached,
      isNull,
    );
    expect(
      ProfessionalOppositionGoalTarget(
        protocol: lower,
        value: 90,
        best: 80,
        hasLatestEvidence: true,
      ).reached,
      isNull,
    );
  });
  test(
    'API anterior conserva récord sin presentarlo como última evaluación',
    () {
      final row = <String, dynamic>{
        'revision': 1,
        'title': 'Meta',
        'can_edit': true,
        'history_complete': true,
        'targets': [
          {
            'value': 90,
            'best': 80,
            'protocol': {
              'id': 'run',
              'name': 'Carrera',
              'unit': 'seconds',
              'direction': 'lower',
              'resolution': .01,
              'instructions': 'Recorre el trazado medido.',
              'max_attempts': 1,
              'retry_policy': 'none',
              'source': 'custom',
              'protocol_id': 'protocol',
              'protocol_fingerprint': 'fingerprint',
              'protocol_version': 1,
            },
          },
        ],
      };
      final old = ProfessionalOppositionGoal.fromJson(row).targets.single;
      expect(old.best, 80);
      expect(old.hasLatestEvidence, false);
      expect(old.reached, isNull);
      final target = Map<String, dynamic>.from(
        (row['targets'] as List).single as Map,
      );
      row['targets'] = <Map<String, dynamic>>[target];
      target.addAll({
        'latest': null,
        'latest_at': '2026-10-25T10:00:00Z',
        'previous': 85,
        'previous_at': '2026-10-20T10:00:00Z',
      });
      final current = ProfessionalOppositionGoal.fromJson(row).targets.single;
      expect(current.hasLatestEvidence, true);
      expect(current.latest, isNull);
      expect(current.reached, isNull);
      expect(current.favorableChange, isNull);
    },
  );
  testWidgets(
    'última marca y evolución tienen prioridad sobre un récord antiguo',
    (tester) async {
      final repo = FakeGoals()
        ..goal = ProfessionalOppositionGoal(
          revision: 1,
          title: 'Convocatoria 2027',
          targets: [
            ProfessionalOppositionGoalTarget(
              protocol: protocol(),
              value: 90,
              best: 80,
              latest: 92,
              previous: 94,
              latestAt: DateTime.utc(2026, 10, 25),
              hasLatestEvidence: true,
            ),
          ],
        );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Última: 1:32 · Meta: 1:30'), findsOneWidget);
      expect(
        find.text('Mejora de 0:02 respecto a la evaluación anterior'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Mejor marca consultada: 1:20'),
        findsOneWidget,
      );
      expect(find.textContaining('Meta alcanzada'), findsNothing);
      repo.goal = ProfessionalOppositionGoal(
        revision: 1,
        title: 'Convocatoria 2027',
        targets: [
          ProfessionalOppositionGoalTarget(
            protocol: protocol(),
            value: 90,
            best: 80,
            latest: 89,
            previous: 92,
            latestAt: DateTime.utc(2026, 10, 26),
            hasLatestEvidence: true,
          ),
        ],
      );
      await tester.tap(find.byTooltip('Actualizar objetivo'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Meta alcanzada en esta evaluación'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'resumen compacto, muestra ausencia y declara historial parcial',
    (tester) async {
      final repo = FakeGoals()
        ..goal = ProfessionalOppositionGoal(
          revision: 1,
          title: 'Bomberos 2027',
          targets: [
            for (var i = 0; i < 5; i++)
              ProfessionalOppositionGoalTarget(
                protocol: protocol(id: '$i'),
                value: 90,
              ),
          ],
          historyComplete: false,
          evaluationsConsidered: 200,
        );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Bomberos 2027'), findsOneWidget);
      expect(find.text('Sin marca válida comparable'), findsNWidgets(3));
      expect(find.textContaining('Historial parcial'), findsOneWidget);
      await tester.tap(find.text('Ver las 5 metas'));
      await tester.pumpAndSettle();
      expect(find.text('Sin marca válida comparable'), findsNWidgets(5));
    },
  );
  testWidgets(
    'reintento conserva operación, revisión y contenido de envío incierto',
    (tester) async {
      final repo = FakeGoals()..fail = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir objetivo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Convocatoria o preparación'),
        'Policía 2027',
      );
      await tester.tap(find.text('Guardar objetivo'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar guardado pendiente'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Confirmar guardado pendiente'));
      await tester.pumpAndSettle();
      expect(repo.writes.length, 2);
      expect(repo.writes[0].operation, repo.writes[1].operation);
      expect(repo.writes[0].revision, repo.writes[1].revision);
      expect(identical(repo.writes[0].draft, repo.writes[1].draft), true);
      expect(find.text('Policía 2027'), findsOneWidget);
    },
  );
  testWidgets(
    'reconstruir un adaptador de la misma cuenta conserva el envío incierto',
    (tester) async {
      final first = FakeGoals()..fail = true;
      await tester.pumpWidget(app(first));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir objetivo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Convocatoria o preparación'),
        'Bomberos 2027',
      );
      await tester.tap(find.text('Guardar objetivo'));
      await tester.pumpAndSettle();
      final next = FakeGoals()..stableScope = first.scope;
      await tester.pumpWidget(app(next));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar guardado pendiente'), findsOneWidget);
      await tester.tap(find.text('Confirmar guardado pendiente'));
      await tester.pumpAndSettle();
      expect(next.writes.single.operation, first.writes.single.operation);
      expect(
        identical(next.writes.single.draft, first.writes.single.draft),
        true,
      );
      expect(find.text('Bomberos 2027'), findsOneWidget);
    },
  );
  testWidgets(
    'navegación lateral conserva envío incierto y confirma el mismo recibo antes de salir',
    (tester) async {
      final repo = FakeGoals()..fail = true;
      final exits = WorkflowExitRegistry();
      final router = GoRouter(
        initialLocation: '/student',
        routes: [
          GoRoute(
            path: '/student',
            onExit: (_, state) => exits.requestExit(state.pageKey),
            builder: (_, state) => WorkflowExitScope(
              controller: exits.controller(state.pageKey),
              child: Scaffold(
                appBar: AppBar(
                  actions: [
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => context.go('/agenda'),
                        child: const Text('Abrir agenda'),
                      ),
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  child: TrainerClientGoalsPanel(
                    repository: repo,
                    clientId: 'student',
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/agenda',
            builder: (_, _) => const Scaffold(body: Text('Agenda abierta')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Definir objetivo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Convocatoria o preparación'),
        'Policía 2027',
      );
      await tester.tap(find.text('Guardar objetivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Guardado pendiente de confirmación'), findsOneWidget);
      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar guardado pendiente'), findsOneWidget);
      expect(find.text('Agenda abierta'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Abrir agenda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y salir'));
      await tester.pumpAndSettle();
      expect(find.text('Agenda abierta'), findsOneWidget);
      expect(repo.writes.length, 2);
      expect(repo.writes.first.operation, repo.writes.last.operation);
      expect(repo.writes.first.revision, repo.writes.last.revision);
      expect(identical(repo.writes.first.draft, repo.writes.last.draft), true);
    },
  );
  test(
    'repositorio fija propietario y respeta permiso de lectura del servidor',
    () async {
      final server = ProgramWorkServer();
      addTearDown(server.client.dispose);
      await server.login();
      server.respond = (request, name, params) async {
        expect(params['p_expected_owner'], owner);
        if (name == 'list_trainer_goal_protocols') {
          return server.json(request, []);
        }
        expect(params['p_client_id'], 'student');
        if (name == 'get_trainer_client_goal') {
          return server.json(request, {
            'revision': 0,
            'title': '',
            'targets': [],
            'can_edit': false,
            'history_complete': true,
          });
        }
        expect(name, 'save_trainer_client_goal');
        expect(params['p_expected_revision'], 0);
        expect(params['p_payload'], {
          'title': 'Convocatoria 2027',
          'target_date': null,
          'targets': [],
        });
        return server.json(request, 1);
      };
      final repository = SupabaseTrainerClientGoalsRepository(
        server.client,
        owner,
      );
      expect((await repository.get('student')).canEdit, false);
      expect(await repository.protocols(), isEmpty);
      expect(
        await repository.save(
          'operation',
          'student',
          0,
          ProfessionalOppositionGoalDraft(title: 'Convocatoria 2027'),
        ),
        1,
      );
      expect(server.calls.length, 3);
    },
  );
  test(
    'el servidor rechaza credenciales sustituidas después del control local',
    () async {
      final server = ProgramWorkServer();
      addTearDown(server.client.dispose);
      await server.login();
      server.replaceTransportIdentity = true;
      server.respond = (_, _, _) async =>
          throw StateError('No debe alcanzar la lectura');
      final repository = SupabaseTrainerClientGoalsRepository(
        server.client,
        owner,
      );
      await expectLater(
        repository.get('student'),
        throwsA(isA<PostgrestException>()),
      );
      expect(server.calls.single.params['p_expected_owner'], owner);
    },
  );
  testWidgets('objetivo y acciones legibles a 320px con texto doble', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerClientGoalsPanel(
              repository: FakeGoals(),
              clientId: 'student',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Definir objetivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cartera histórica se consulta sin ofrecer edición', (
    tester,
  ) async {
    final repo = FakeGoals()
      ..goal = ProfessionalOppositionGoal(
        revision: 1,
        title: 'Meta conservada',
        canEdit: false,
      );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Meta conservada'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });
}
