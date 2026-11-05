import 'dart:async';
import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/programs/data/admin_builtin_assessment_authoring_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_builtin_assessment_authoring_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> definition({bool fas = false}) => fas
    ? {
        'programId': 'fas_periodic_assessment',
        'version': 'score_v2',
        'name': 'Evaluación FAS',
        'description': '',
        'sourceUrl': 'https://www.boe.es/referencia',
        'effectiveFrom': '2027-01-01',
        'minimumPointsPerTest': 20,
        'sourceNotes': ['Se conserva una anomalía documentada de la fuente.'],
        'ageBands': [
          {'id': '17_25', 'minAge': 17, 'maxAge': 25},
          {'id': '26_30', 'minAge': 26, 'maxAge': 30},
        ],
        'tests': [
          {
            'id': 'push',
            'name': 'Flexiones',
            'unit': 'repetitions',
            'betterDirection': 'higher',
            'categoriesPerAgeBand': true,
            'rows': [
              for (var n = 30; n > 0; n--)
                [
                  n,
                  [n, n + 1, n + 2, n + 3],
                ],
            ],
          },
        ],
      }
    : {
        'schemaVersion': 1,
        'programId': 'armed_forces_troop_entry',
        'version': 'catalog_v2',
        'name': 'Ingreso Tropa',
        'description': '',
        'sourceUrl': 'https://www.boe.es/referencia',
        'effectiveFrom': '2026-01-22',
        'tests': [
          {
            'id': 'push',
            'name': 'Flexiones',
            'unit': 'repetitions',
            'betterDirection': 'higher',
          },
        ],
        'standards': [
          for (final category in ['men', 'women'])
            for (final group in [
              'entry',
              'end_of_general_military_training',
              'end_of_training',
            ])
              {
                'testId': 'push',
                'category': category,
                'group': group,
                'threshold': 9,
              },
        ],
      };

AdminBuiltinAssessmentRevision revision({
  String id = 'draft',
  String status = 'draft',
  int editVersion = 1,
  int number = 2,
  String? baseId = 'base',
  bool fas = false,
  Map<String, dynamic>? data,
}) => AdminBuiltinAssessmentRevision(
  id: id,
  programId: fas ? 'fas_periodic_assessment' : 'armed_forces_troop_entry',
  revision: number,
  status: status,
  definition: data ?? definition(fas: fas),
  catalogVersion: 'catalog_v$number',
  scoringVersion: 'score_v$number',
  editVersion: editVersion,
  changeReason: 'Revisión de prueba',
  baseId: baseId,
);

class Repository implements AdminBuiltinAssessmentAuthoringRepository {
  Repository({bool draft = true, this.fas = false}) {
    rows = [
      revision(
        id: 'base',
        status: 'published',
        number: 1,
        baseId: null,
        fas: fas,
      ),
    ];
    if (draft) rows.add(revision(fas: fas));
  }
  final bool fas;
  late List<AdminBuiltinAssessmentRevision> rows;
  String? current = 'base';
  bool failSave = false, failCreate = false;
  int reviews = 0, saves = 0, publishes = 0, withdrawals = 0;
  final requests = <String>[];
  final previewCalls = <Map<String, dynamic>>[];
  final saveVersions = <int>[];
  Completer<AdminBuiltinAssessmentRevision>? delayedSave;
  Map<String, dynamic>? saved;

  @override
  Future<AdminBuiltinAssessmentWorkspace> workspace(String id) async =>
      AdminBuiltinAssessmentWorkspace(
        revisions: rows.toList(),
        currentRevisionId: current,
      );
  @override
  Future<AdminBuiltinAssessmentRevision> createRevision({
    required String programId,
    required String baseId,
    required String requestId,
  }) async {
    requests.add(requestId);
    if (failCreate) {
      failCreate = false;
      throw StateError('response lost');
    }
    final row = revision(fas: fas);
    rows.add(row);
    return row;
  }

  @override
  Future<AdminBuiltinAssessmentRevision> save({
    required AdminBuiltinAssessmentRevision revision,
    required Map<String, dynamic> definition,
    required String changeReason,
  }) async {
    saves++;
    saveVersions.add(revision.editVersion);
    saved = copyBuiltinDefinition(definition);
    if (failSave) throw StateError('offline');
    if (delayedSave != null) return delayedSave!.future;
    final row = AdminBuiltinAssessmentRevision(
      id: revision.id,
      programId: revision.programId,
      revision: revision.revision,
      status: 'draft',
      definition: copyBuiltinDefinition(definition),
      catalogVersion: revision.catalogVersion,
      scoringVersion: revision.scoringVersion,
      editVersion: revision.editVersion + 1,
      changeReason: changeReason,
      baseId: revision.baseId,
    );
    rows = [for (final item in rows) item.id == row.id ? row : item];
    return row;
  }

  @override
  Future<AdminBuiltinAssessmentReview> review(String id) async {
    reviews++;
    return const AdminBuiltinAssessmentReview(
      issues: [],
      warnings: ['Comprueba la fuente.'],
      changeCount: 1,
      existingGoalsPreserved: 3,
    );
  }

  @override
  Future<AdminBuiltinAssessmentRevision> publish(
    AdminBuiltinAssessmentRevision row,
  ) async {
    publishes++;
    final next = revision(
      id: row.id,
      status: 'published',
      editVersion: row.editVersion,
      data: row.definition,
      fas: fas,
    );
    rows = [for (final item in rows) item.id == row.id ? next : item];
    current = row.id;
    return next;
  }

  @override
  Future<AdminBuiltinAssessmentRevision> withdraw(
    AdminBuiltinAssessmentRevision row,
  ) async {
    withdrawals++;
    final next = revision(
      id: row.id,
      status: 'withdrawn',
      data: row.definition,
      fas: fas,
    );
    rows = [for (final item in rows) item.id == row.id ? next : item];
    if (current == row.id) current = null;
    return next;
  }

  @override
  Future<Map<String, dynamic>> preview({
    required String revisionId,
    required String category,
    required List<Map<String, dynamic>> marks,
    int? age,
    String? milestone,
  }) async {
    previewCalls.add({
      'revision': revisionId,
      'category': category,
      'marks': marks,
      'age': age,
      'milestone': milestone,
    });
    return {
      'results': [
        for (final m in marks)
          {
            'test_id': m['test_id'],
            'name': 'Flexiones',
            'unit': 'repetitions',
            'direction': 'higher',
            'mark': m['value'],
            'threshold': 9,
            'meets_minimum': true,
            'points': fas ? 25 : null,
          },
      ],
      'meets_all_minimums': true,
      'catalog_version': 'c',
      'scoring_version': 's',
    };
  }
}

Future<void> mount(
  WidgetTester t,
  Repository repo, {
  double width = 1100,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminBuiltinAssessmentAuthoringPanel(
            programId: repo.fas
                ? 'fas_periodic_assessment'
                : 'armed_forces_troop_entry',
            repository: repo,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String label) async {
  final finder = find.text(label).first;
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'guardar conserva cambios tras fallo y revisión caduca al volver a editar',
    (t) async {
      final repo = Repository()..failSave = true;
      await mount(t, repo);
      await t.enterText(
        find.byKey(const ValueKey('builtin-authoring-name')),
        'Tropa revisada',
      );
      await tapText(t, 'Editar mínimo');
      await t.enterText(find.byType(TextFormField).last, '11');
      await tapText(t, 'Aplicar al borrador');
      await tapText(t, 'Guardar borrador');
      expect(find.textContaining('Tus cambios se conservan'), findsOneWidget);
      expect(find.text('Tropa revisada'), findsOneWidget);
      expect((repo.saved!['standards'] as List).first['threshold'], 11);
      expect((repo.saved!['tests'] as List).first['betterDirection'], 'higher');
      repo.failSave = false;
      await tapText(t, 'Guardar borrador');
      expect(repo.saveVersions, [1, 1]);
      await tapText(t, 'Revisar antes de publicar');
      expect(repo.reviews, 1);
      FilledButton publish() => t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publicar revisión'),
      );
      expect(publish().onPressed, isNotNull);
      await t.ensureVisible(
        find.byKey(const ValueKey('builtin-authoring-name')),
      );
      await t.enterText(
        find.byKey(const ValueKey('builtin-authoring-name')),
        'Otra corrección',
      );
      await t.pump();
      expect(publish().onPressed, isNull);
      await tapText(t, 'Guardar borrador');
      await tapText(t, 'Revisar antes de publicar');
      await tapText(t, 'Publicar revisión');
      await tapText(t, 'Publicar esta revisión');
      expect(repo.publishes, 1);
      expect(repo.current, 'draft');
      expect(repo.rows.first.definition['name'], 'Ingreso Tropa');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'crear revisión reintenta la misma solicitud si la respuesta se pierde',
    (t) async {
      final repo = Repository(draft: false)..failCreate = true;
      await mount(t, repo);
      await tapText(t, 'Crear revisión');
      expect(find.textContaining('no se duplicará'), findsOneWidget);
      await tapText(t, 'Crear revisión');
      expect(repo.requests.length, 2);
      expect(repo.requests[0], repo.requests[1]);
      expect(find.text('Revisión 2 · Borrador'), findsOneWidget);
    },
  );

  testWidgets(
    'FAS edita una celda conservando matriz, notas y filas paginadas',
    (t) async {
      final repo = Repository(fas: true);
      await mount(t, repo, width: 320, scale: 2);
      expect(t.takeException(), isNull);
      await tapText(t, 'Editar puntos');
      await t.enterText(find.byType(TextFormField).last, '80');
      await tapText(t, 'Aplicar al borrador');
      await tapText(t, 'Guardar borrador');
      final test = (repo.saved!['tests'] as List).first;
      expect(test['rows'][0][0], 30);
      expect(test['rows'][0][1], [80, 31, 32, 33]);
      expect(test['rows'].length, 30);
      expect(repo.saved!['minimumPointsPerTest'], 20);
      expect(repo.saved!['sourceNotes'], definition(fas: true)['sourceNotes']);
      await tapText(t, 'Filas siguientes');
      expect(find.text('Página 2 de 2 · 30 filas'), findsOneWidget);
      expect(find.text('1 repeticiones'), findsOneWidget);
      await tapText(t, 'Comparar con la versión de origen');
      await tapText(t, 'Simular y comparar resultados');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('simula el borrador guardado y su origen sin guardar intentos', (
    t,
  ) async {
    final repo = Repository();
    await mount(t, repo);
    await tapText(t, 'Simular y comparar resultados');
    final field = find.byKey(const ValueKey('builtin-preview-push'));
    await t.ensureVisible(field);
    await t.enterText(field, '12');
    await tapText(t, 'Simular estas marcas');
    expect(repo.previewCalls.length, 2);
    expect(repo.previewCalls.map((c) => c['revision']), ['draft', 'base']);
    expect(repo.previewCalls.first['marks'], [
      {'test_id': 'push', 'value': 12},
    ]);
    expect(repo.saves, 0);
    expect(find.text('Base: Cumple mínimo'), findsOneWidget);
    expect(find.text('Versión seleccionada: Cumple mínimo'), findsOneWidget);
  });

  testWidgets('ignora un guardado tardío después de cambiar de repositorio', (
    t,
  ) async {
    final repo = Repository()
      ..delayedSave = Completer<AdminBuiltinAssessmentRevision>();
    await mount(t, repo);
    await t.enterText(
      find.byKey(const ValueKey('builtin-authoring-name')),
      'Respuesta antigua',
    );
    await t.ensureVisible(find.text('Guardar borrador').first);
    await t.tap(find.text('Guardar borrador').first);
    await t.pump();
    final next = Repository();
    next.rows = [
      revision(id: 'nuevo', data: {...definition(), 'name': 'Contexto nuevo'}),
    ];
    await mount(t, next);
    repo.delayedSave!.complete(
      revision(data: {...definition(), 'name': 'Respuesta antigua'}),
    );
    await t.pumpAndSettle();
    expect(find.text('Contexto nuevo'), findsOneWidget);
    expect(find.text('Respuesta antigua'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'retirar exige confirmación y permite recuperar como otro borrador',
    (t) async {
      final repo = Repository(draft: false);
      await mount(t, repo);
      await tapText(t, 'Retirar para nuevas preparaciones');
      await tapText(t, 'Cancelar');
      expect(repo.withdrawals, 0);
      await tapText(t, 'Retirar para nuevas preparaciones');
      final confirm = find
          .widgetWithText(FilledButton, 'Retirar para nuevas preparaciones')
          .last;
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(repo.withdrawals, 1);
      expect(repo.current, isNull);
      expect(repo.rows.single.status, 'withdrawn');
      expect(repo.rows.single.definition, definition());
      await tapText(t, 'Recuperar como borrador');
      expect(repo.rows.length, 2);
      expect(repo.rows.first.status, 'withdrawn');
      expect(repo.rows.last.isDraft, isTrue);
    },
  );

  testWidgets(
    'salir avisa por cambios sin guardar y cancelar conserva el borrador',
    (t) async {
      final repo = Repository();
      final exit = WorkflowExitController();
      await t.pumpWidget(
        MaterialApp(
          home: WorkflowExitScope(
            controller: exit,
            child: Scaffold(
              body: SingleChildScrollView(
                child: AdminBuiltinAssessmentAuthoringPanel(
                  programId: 'armed_forces_troop_entry',
                  repository: repo,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('builtin-authoring-name')),
        'Cambio pendiente',
      );
      final leaving = exit.onExit!();
      await t.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tapText(t, 'Continuar');
      expect(await leaving, isFalse);
      expect(find.text('Cambio pendiente'), findsOneWidget);
      await tapText(t, 'Guardar borrador');
      expect(await exit.onExit!(), isTrue);
    },
  );

  testWidgets('simulador de agilidad conserva milisegundos y edad', (t) async {
    final repo = Repository(fas: true);
    final data = definition(fas: true);
    (data['tests'] as List).first['id'] = 'agility_speed_circuit';
    (data['tests'] as List).first['name'] = 'Agilidad';
    (data['tests'] as List).first['unit'] = 'milliseconds';
    (data['tests'] as List).first['requiredBelowAge'] = 45;
    repo.rows = [
      revision(
        id: 'base',
        status: 'published',
        number: 1,
        baseId: null,
        fas: true,
        data: data,
      ),
      revision(fas: true, data: data),
    ];
    await mount(t, repo);
    await tapText(t, 'Simular y comparar resultados');
    final field = find.byKey(
      const ValueKey('builtin-preview-agility_speed_circuit'),
    );
    await t.ensureVisible(field);
    await t.enterText(field, '13,259');
    await tapText(t, 'Simular estas marcas');
    expect(repo.previewCalls.first['marks'], [
      {'test_id': 'agility_speed_circuit', 'value': 13259},
    ]);
    expect(repo.previewCalls.first['age'], 30);
    expect(repo.previewCalls.first['milestone'], isNull);
    expect(t.takeException(), isNull);
  });

  test('repositorio conserva revisión esperada y serializa RPC sin escrituras directas', () async {
    final calls = <({String path, Map<String, dynamic> body})>[];
    final row = {
      'id': 'draft',
      'program_id': 'armed_forces_troop_entry',
      'revision': 2,
      'status': 'draft',
      'definition': definition(),
      'catalog_version': 'catalog_v2',
      'scoring_version': 'score_v2',
      'edit_version': 4,
      'change_reason': 'Corrección',
    };
    final client = SupabaseClient(
      'http://localhost',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        calls.add((path: request.url.path, body: body));
        Object response = row;
        if (request.url.path.endsWith('workspace')) {
          response = {
            'revisions': [row],
            'current_revision_id': 'draft',
          };
        }
        if (request.url.path.endsWith('review')) {
          response = {
            'issues': [],
            'warnings': [],
            'change_count': 1,
            'existing_goals_preserved': 3,
          };
        }
        if (request.url.path.endsWith('preview')) response = {'results': []};
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseAdminBuiltinAssessmentAuthoringRepository(
      client,
    );
    final workspace = await repository.workspace('armed_forces_troop_entry');
    final draft = workspace.revisions.single;
    await repository.createRevision(
      programId: draft.programId,
      baseId: 'base',
      requestId: 'request',
    );
    await repository.save(
      revision: draft,
      definition: draft.definition,
      changeReason: 'Corrección',
    );
    await repository.review(draft.id);
    await repository.preview(
      revisionId: draft.id,
      category: 'men',
      marks: [
        {'test_id': 'push', 'value': 12},
      ],
      milestone: 'entry',
    );
    await repository.publish(draft);
    await repository.withdraw(draft);
    expect(
      calls.every(
        (c) => c.path.startsWith('/rest/v1/rpc/admin_builtin_assessment_'),
      ),
      isTrue,
    );
    expect(calls[1].body['p_request_id'], 'request');
    expect(calls[2].body['p_expected_edit_version'], 4);
    expect(calls[5].body['p_expected_edit_version'], 4);
    expect(calls[6].body['p_expected_edit_version'], 4);
  });
}
