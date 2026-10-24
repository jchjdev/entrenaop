import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_client_workspace.dart';
import 'package:entrenaop_trainer/trainer_client_workspace_repository.dart';
import 'package:entrenaop_trainer/trainer_csv_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import 'trainer_exercise_repository_test.dart' show ServerFixture, owner;

TrainerClientWorkspace workspace() => TrainerClientWorkspace.fromJson({
  'client': {
    'person_id': 'client',
    'person_name': 'Alumno',
    'created_at': '2026-10-20T12:00:00Z',
    'updated_at': '2026-10-20T12:00:00Z',
    'accepted_at': '2026-10-20T12:00:00Z',
    'ended_at': null,
    'archived_at': null,
    'active_relation_id': 'relation',
    'episode_count': 1,
  },
  'relations': [
    {'id': 'relation', 'accepted_at': '2026-10-20T12:00:00Z', 'ended_at': null},
  ],
  'relations_complete': true,
  'notes': {
    'revision': 2,
    'notes': 'Nota anterior secreta',
    'goal': 'Objetivo interno',
  },
  'can_edit_notes': true,
});
Map<String, dynamic> assignment(
  int id,
  String date, {
  String status = 'planned',
}) => {
  'id': 'assignment-$id',
  'scheduled_date': date,
  'record_date': date,
  'status': status,
  'execution_id': status == 'completed' ? 'execution-$id' : null,
};
Map<String, dynamic> setRow(
  String id,
  String date, {
  String format = 'straight_sets',
}) => {
  'id': id,
  'execution_id': 'execution',
  'exercise_id': 'exercise',
  'exercise_name': 'Dominadas',
  'record_date': date,
  'status': 'completed',
  'block_format': format,
  'actual_reps': 0,
  'actual_load_kg': 0,
  'actual_rpe': null,
  'actual_rir': null,
};

class WorkspaceFixture extends TrainerClientWorkspaceRepository {
  bool fail = false;
  bool timedReport = false;
  List<Map<String, dynamic>>? reportSets;
  List<Map<String, dynamic>> reportAmrap = [];
  final writes =
      <({String operation, int revision, String notes, String goal})>[];
  @override
  Future<TrainerClientWorkspace> get(String clientId) async => workspace();
  @override
  Future<int> saveNotes(
    String operationId,
    String clientId,
    int expectedRevision, {
    required String notes,
    required String goal,
  }) async {
    writes.add((
      operation: operationId,
      revision: expectedRevision,
      notes: notes,
      goal: goal,
    ));
    if (fail) throw StateError('Sin conexión');
    return expectedRevision + 1;
  }

  @override
  Future<TrainerClientProgressReport> progress(
    String clientId,
    DateTime start,
    DateTime endExclusive,
  ) async => TrainerClientProgressReport(
    start: start,
    endExclusive: endExclusive,
    asOfDate: DateTime.now().toUtc(),
    assignments: [],
    sets:
        reportSets ??
        (timedReport
            ? [
                {
                  ...setRow(
                    'one',
                    DateTime.now().toUtc().toIso8601String().substring(0, 10),
                  ),
                  'actual_duration_seconds': 89,
                },
              ]
            : []),
    amrap: reportAmrap,
  );
}

class ProgressServer extends ServerFixture {
  bool changeTotal = false, truncated = false, changedValues = false;
  int assignmentCalls = 0;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (!request.url.path.endsWith('/rpc/get_trainer_client_progress')) {
      return super.handle(request);
    }
    final body = jsonDecode(request.body) as Map;
    final kind = body['p_kind'];
    final next = body['p_before_id'] != null;
    if (kind == 'assignments') assignmentCalls++;
    final page = kind != 'assignments'
        ? []
        : next
        ? [assignment(200, '2026-10-20')]
        : List.generate(200, (i) => assignment(i, '2026-10-20'));
    return super.json(request, {
      'items': page,
      'total': kind == 'assignments' ? (changeTotal && next ? 202 : 201) : 0,
      'has_more': kind == 'assignments' && !next && !truncated,
      'fingerprint': changedValues && next ? 'changed' : 'same',
      'date_basis': kind == 'assignments'
          ? 'scheduled_civil_date'
          : 'execution_started_at_utc',
    });
  }
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'informe plegable oculta métricas sin observaciones y conserva los ceros reales',
    (tester) async {
      final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final repo = WorkspaceFixture()
        ..reportSets = [
          {...setRow('one', date), 'actual_duration_seconds': 87},
          {...setRow('two', date), 'actual_reps': null, 'actual_load_kg': null},
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientWorkspacePage(
            repository: repo,
            clientId: 'client',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dominadas'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Medida registrada'), findsNothing);
      await tapText(tester, 'Dominadas');
      expect(find.text('Repeticiones'), findsOneWidget);
      expect(find.text('Tiempo'), findsOneWidget);
      expect(find.text('Carga externa'), findsOneWidget);
      expect(find.text('0 rep'), findsNWidgets(2));
      expect(find.text('0 kg'), findsNWidgets(2));
      expect(find.text('Distancia'), findsNothing);
      expect(find.text('Esfuerzo'), findsNothing);
      expect(find.text('Margen'), findsNothing);
      expect(find.text('Sin dato'), findsNothing);
      final rows = tester.widget<DataTable>(find.byType(DataTable)).rows;
      expect((rows.first.cells[2].child as Text).data, '1');
      await tapText(tester, 'Dominadas');
      expect(find.text('Medida registrada'), findsNothing);
      await tapText(tester, 'Dominadas');
      expect(find.text('0 rep'), findsNWidgets(2));
      expect(repo.writes, isEmpty);
    },
  );
  testWidgets(
    'ejercicio sin mediciones evita tabla vacía y AMRAP se puede plegar a 320 px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final repo = WorkspaceFixture()
        ..reportSets = [
          {
            ...setRow('one', date),
            'actual_reps': null,
            'actual_load_kg': null,
            'status': 'skipped',
          },
        ]
        ..reportAmrap = [
          {
            'execution_id': 'execution',
            'block_order': 1,
            'record_date': date,
            'completed_rounds': 4,
            'partial_item_order': 0,
            'partial_reps': 3,
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TrainerClientWorkspacePage(
            repository: repo,
            clientId: 'client',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Las notas tienen scroll propio; aquí movemos la lista de la ficha.
      for (
        var i = 0;
        i < 25 && find.text('Dominadas').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      await tapText(tester, 'Dominadas');
      expect(find.byType(DataTable), findsNothing);
      expect(
        find.text('No hay mediciones registradas para este ejercicio.'),
        findsOneWidget,
      );
      await tapText(tester, 'AMRAP: resultados de bloque');
      expect(find.textContaining('4 rondas completas'), findsOneWidget);
      await tapText(tester, 'AMRAP: resultados de bloque');
      expect(find.textContaining('4 rondas completas'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(repo.writes, isEmpty);
    },
  );

  testWidgets(
    'el informe profesional muestra mínimos y máximos en minutos y segundos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientWorkspacePage(
            repository: WorkspaceFixture()..timedReport = true,
            clientId: 'client',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Dominadas');
      await tester.scrollUntilVisible(
        find.text('Tiempo'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1:29'), findsNWidgets(2));
      expect(find.text('89 s'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancelar salida lateral conserva objetivo y notas sucios', (
    tester,
  ) async {
    final exits = WorkflowExitRegistry();
    final router = GoRouter(
      initialLocation: '/client',
      routes: [
        GoRoute(
          path: '/client',
          onExit: (_, state) => exits.requestExit(state.pageKey),
          builder: (_, state) => WorkflowExitScope(
            controller: exits.controller(state.pageKey),
            child: TrainerClientWorkspacePage(
              repository: WorkspaceFixture(),
              clientId: 'client',
            ),
          ),
        ),
        GoRoute(
          path: '/elsewhere',
          builder: (_, _) => const Scaffold(body: Text('Otro destino')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Objetivo interno'),
      'Mi objetivo pendiente',
    );
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainerClientWorkspacePage), findsOneWidget);
    expect(find.text('Otro destino'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Objetivo interno'))
          .controller!
          .text,
      'Mi objetivo pendiente',
    );
  });
  testWidgets('ficha admite pantalla estrecha con texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TrainerClientWorkspacePage(
          repository: WorkspaceFixture(),
          clientId: 'client',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test(
    'informe conserva cero/ausentes, excluye AMRAP y no penaliza futuro',
    () {
      final report = TrainerClientProgressReport(
        start: DateTime.utc(2026, 10, 20),
        endExclusive: DateTime.utc(2026, 10, 23),
        asOfDate: DateTime.utc(2026, 10, 21),
        assignments: [
          assignment(1, '2026-10-20', status: 'completed'),
          assignment(2, '2026-10-22'),
        ],
        sets: [
          setRow('normal', '2026-10-20'),
          setRow('reference', '2026-10-20', format: 'amrap'),
        ],
        amrap: [],
      );
      expect(report.compliance.completedFraction, 1);
      expect(report.compliance.todayAndFutureCount, 1);
      final progress = report.results.exercises['exercise']!;
      expect(progress.reps.minimum, 0);
      expect(progress.loadKg.minimum, 0);
      expect(progress.rpe.recordedCount, 0);
      expect(progress.rpe.missingCount, 1);
      expect(progress.rpe.mean, isNull);
      expect(report.results.amrapReferenceSetsExcluded, 1);
    },
  );
  test('sin citas evaluables no fabrica porcentaje', () {
    final report = TrainerClientProgressReport(
      start: DateTime.utc(2026, 10, 20),
      endExclusive: DateTime.utc(2026, 10, 21),
      asOfDate: DateTime.utc(2026, 10, 21),
      assignments: [],
      sets: [],
      amrap: [],
    );
    expect(report.compliance.completedFraction, isNull);
    expect(report.results.exercises, isEmpty);
  });
  test('CSV escapa comillas y líneas y neutraliza fórmulas solo en texto', () {
    final csv = trainerCsvEncode([
      [
        '=SUM(A1)',
        ' +comando',
        '-nombre',
        '@comando',
        'Texto,"doble"\nOtra línea',
        -2,
        0,
        null,
      ],
    ]);
    expect(csv, contains('"\'=SUM(A1)"'));
    expect(csv, contains('"\' +comando"'));
    expect(csv, contains('"\'-nombre"'));
    expect(csv, contains('"\'@comando"'));
    expect(csv, contains('"Texto,""doble""\nOtra línea"'));
    expect(csv, endsWith(',-2,0,'));
    expect(
      () => trainerCsvEncode([
        [double.nan],
      ]),
      throwsFormatException,
    );
  });
  test('CSV declara criterios de fecha y no introduce notas privadas', () {
    final report = TrainerClientProgressReport(
      start: DateTime.utc(2026, 10, 20),
      endExclusive: DateTime.utc(2026, 10, 21),
      asOfDate: DateTime.utc(2026, 10, 21),
      assignments: [assignment(1, '2026-10-20')],
      sets: [setRow('set', '2026-10-20')],
      amrap: [],
    );
    final csv = trainerClientReportCsv('=Alumno', report);
    expect(csv, contains('fecha_civil_pautada'));
    expect(csv, contains('fecha_inicio_ejecucion_UTC'));
    expect(csv, contains('"\'=Alumno"'));
    expect(csv, isNot(contains(workspace().notes)));
  });
  test('stub nativo permite ofrecer copia sin fingir una descarga', () async {
    expect(await downloadTrainerCsv('informe.csv', 'a,b'), isFalse);
  });
  test(
    'repositorio carga todas las páginas antes de computar cumplimiento',
    () async {
      final server = ProgressServer();
      addTearDown(server.client.dispose);
      await server.client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      final report =
          await SupabaseTrainerClientWorkspaceRepository(
            server.client,
            owner,
          ).progress(
            'client',
            DateTime.utc(2026, 10, 20),
            DateTime.utc(2026, 10, 21),
          );
      expect(server.assignmentCalls, 2);
      expect(report.assignments, hasLength(201));
      expect(report.compliance.eligibleCount, 201);
    },
  );
  for (final mode in ['change', 'truncated', 'values']) {
    test(
      'repositorio rechaza un informe $mode en vez de mostrar totales parciales',
      () async {
        final server = ProgressServer()
          ..changeTotal = mode == 'change'
          ..truncated = mode == 'truncated'
          ..changedValues = mode == 'values';
        addTearDown(server.client.dispose);
        await server.client.auth.signInWithPassword(
          email: 'fixture@example.invalid',
          password: 'fixture',
        );
        await expectLater(
          SupabaseTrainerClientWorkspaceRepository(
            server.client,
            owner,
          ).progress(
            'client',
            DateTime.utc(2026, 10, 20),
            DateTime.utc(2026, 10, 21),
          ),
          throwsStateError,
        );
      },
    );
  }
  testWidgets('ficha carga por clienteId y conserva notas en reintento', (
    tester,
  ) async {
    final repo = WorkspaceFixture()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientWorkspacePage(repository: repo, clientId: 'client'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alumno'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Notas internas'),
      'Mi borrador',
    );
    await tapText(tester, 'Guardar notas internas');
    expect(repo.writes, hasLength(1));
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Notas internas'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mi borrador'), findsOneWidget);
    repo.fail = false;
    await tapText(tester, 'Reintentar notas');
    expect(repo.writes, hasLength(2));
    expect(repo.writes.first, repo.writes.last);
    expect(repo.writes.first.revision, 2);
    await tester.scrollUntilVisible(
      find.text('Notas internas guardadas.'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Notas internas guardadas.'), findsOneWidget);
  });
  testWidgets('informe vacío muestra ausencia y no un falso cero por ciento', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientWorkspacePage(
          repository: WorkspaceFixture(),
          clientId: 'client',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sin citas evaluables en este periodo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin citas evaluables en este periodo'), findsOneWidget);
    expect(find.textContaining('0 %'), findsNothing);
  });
}
