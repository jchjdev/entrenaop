import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_groups_page.dart';
import 'package:entrenaop_trainer/trainer_groups_repository.dart';
import 'package:entrenaop_trainer/trainer_week_copy_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/workout_template.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_program_flow_test.dart' show ProgramFixture;
import 'trainer_workout_flow_test.dart' show WorkoutFixture, privateRecipe;

TrainerGroup group({bool inactive = false}) => TrainerGroup.fromJson({
  'id': 'group',
  'name': 'Convocatoria de prueba',
  'revision': 3,
  'updated_at': '2026-10-21T10:00:00Z',
  'members': [
    {'client_id': 'ana', 'client_name': 'Ana', 'relation_id': 'relation-ana'},
    {
      'client_id': 'luis',
      'client_name': 'Luis',
      'relation_id': inactive ? null : 'relation-luis',
    },
  ],
});
FakeTrainerRepository access() => FakeTrainerRepository()
  ..active = [
    for (final name in ['Ana', 'Luis'])
      TrainerRelation.fromJson({
        'id': 'relation-${name.toLowerCase()}',
        'person_id': name.toLowerCase(),
        'person_name': name,
        'accepted_at': '2026-10-21T10:00:00Z',
      }),
  ];

class GroupsFixture extends TrainerGroupsRepository {
  List<TrainerGroup> rows = [group()];
  bool failGroup = false,
      failBatch = false,
      staleBatch = false,
      failCopy = false,
      staleCopy = false;
  int previewCount = 0, copySize = 2, excluded = 1;
  final saved = <({String op, String id, String name, List<String> clients})>[];
  final sent = <({String op, Map<String, dynamic> params})>[];
  final copies =
      <({String op, String fingerprint, DateTime week, int offset})>[];
  final prepared = <TrainerBatchRequest>[];
  @override
  Future<List<TrainerGroup>> groups({TrainerGroup? before}) async =>
      before == null ? rows : [];
  @override
  Future<void> saveGroup({
    required String operationId,
    required String id,
    required int expectedRevision,
    required String name,
    required List<String> clientIds,
  }) async {
    saved.add((
      op: operationId,
      id: id,
      name: name,
      clients: List.of(clientIds),
    ));
    if (failGroup) throw StateError('Incierto');
  }

  @override
  Future<TrainerBatchPreview> previewBatch(TrainerBatchRequest request) async {
    prepared.add(request);
    return TrainerBatchPreview.fromJson({
      'fingerprint': 'batch-${prepared.length}',
      'assignment_count':
          request.recipients.length *
          (request.programId == null ? 1 : request.entries.length),
      'preview': [
        for (final member in request.recipients)
          {
            'client_id': member.clientId,
            'client_name': member.name,
            'dates': [
              if (request.date != null)
                request.date!.toIso8601String().split('T').first,
              for (final entry in request.entries) entry.toJson()['date'],
            ],
            'coincidences': member.clientId == 'ana'
                ? [
                    {'date': '2026-10-22'},
                  ]
                : [],
          },
      ],
    });
  }

  @override
  Future<TrainerBatchReceipt> deliverBatch(
    String operationId,
    TrainerBatchRequest request,
    String fingerprint,
  ) async {
    sent.add((
      op: operationId,
      params: Map<String, dynamic>.from(
        jsonDecode(
          jsonEncode({...request.toParams(), 'p_fingerprint': fingerprint}),
        ) as Map,
      ),
    ));
    if (failBatch) throw StateError('Incierto');
    if (staleBatch) {
      throw const PostgrestException(
        message: 'Cambió la agenda',
        code: '40001',
      );
    }
    return TrainerBatchReceipt.fromJson({
      'assignment_count':
          request.recipients.length *
          (request.programId == null ? 1 : request.entries.length),
      'recipients': [
        for (final member in request.recipients)
          {
            'client_id': member.clientId,
            'assignment_ids': [
              for (
                var i = 0;
                i < (request.programId == null ? 1 : request.entries.length);
                i++
              )
                '${member.clientId}-$i',
            ],
          },
      ],
    });
  }

  @override
  Future<TrainerWeekCopyPreview> previewWeek(
    DateTime weekStart,
    int offsetDays,
  ) async {
    previewCount++;
    return TrainerWeekCopyPreview.fromJson({
      'fingerprint': 'fingerprint-$previewCount',
      'excluded_count': excluded,
      'items': [
        for (var i = 0; i < copySize; i++)
          {
            'id': 'source-$i',
            'client_id': i % 2 == 0 ? 'ana' : 'luis',
            'client_name': i % 2 == 0 ? 'Ana' : 'Luis',
            'template_id': 'template',
            'template_name': 'Receta fijada $i',
            'date': '2026-10-21',
            'target_date': '2026-10-28',
            'note': null,
            'has_date_coincidence': i == 0,
          },
      ],
    });
  }

  @override
  Future<TrainerWeekCopyReceipt> copyWeek(
    String operationId,
    DateTime weekStart,
    int offsetDays,
    String fingerprint,
  ) async {
    copies.add((
      op: operationId,
      fingerprint: fingerprint,
      week: weekStart,
      offset: offsetDays,
    ));
    if (staleCopy) {
      throw const PostgrestException(message: 'Actualiza', code: '40001');
    }
    if (failCopy) throw StateError('Incierto');
    return TrainerWeekCopyReceipt.fromJson({
      'assignment_count': copySize,
      'assignments': [
        for (var i = 0; i < copySize; i++)
          {'client_id': i % 2 == 0 ? 'ana' : 'luis'},
      ],
    });
  }

  @override
  Future<WorkoutTemplate?> template(String id) async => privateRecipe;
}

Widget app(Widget page, {double scale = 1}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);
Widget openBatch(GroupsFixture repo, {double scale = 1}) => app(
  Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => TrainerBatchAssignmentDialog(
            repository: repo,
            access: access(),
            workouts: WorkoutFixture(),
            programs: ProgramFixture(),
            group: group(),
          ),
        ),
        child: const Text('Abrir envío'),
      ),
    ),
  ),
  scale: scale,
);
Widget openCopy(GroupsFixture repo, {double scale = 1}) => app(
  Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        onPressed: () =>
            showTrainerWeekCopyDialog(context, repo, DateTime(2026, 10, 19), 7),
        child: const Text('Abrir copia'),
      ),
    ),
  ),
  scale: scale,
);
Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 50,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseDate(WidgetTester tester, Finder finder) async {
  await tap(tester, finder);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> prepareSession(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('trainer-batch-workout')));
  await tester.tap(find.text('Fuerza para pruebas físicas · v3').last);
  await tester.pumpAndSettle();
  await chooseDate(tester, find.byKey(const ValueKey('trainer-batch-date')));
  await tap(tester, find.text('Revisar destinatarios y fechas'));
}

void main() {
  test('payload de tanda conserva fechas civiles y listas inmutables', () {
    final people = [
      const TrainerGroupMember(
        clientId: 'ana',
        name: 'Ana',
        relationId: 'relation',
      ),
    ];
    final request = TrainerBatchRequest(
      recipients: people,
      templateId: 't',
      date: DateTime.utc(2026, 10, 21, 23),
    );
    people.clear();
    expect(request.toParams()['p_date'], '2026-10-21');
    expect(request.recipients.length, 1);
    expect(() => request.recipients.clear(), throwsUnsupportedError);
  });
  testWidgets('guardar grupo incierto congela nombre miembros y orden', (
    tester,
  ) async {
    final repo = GroupsFixture()..failGroup = true;
    await tester.pumpWidget(
      app(
        TrainerGroupsPage(
          repository: repo,
          access: access(),
          workouts: WorkoutFixture(),
          programs: ProgramFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Crear grupo'));
    await tester.enterText(
      find.byKey(const ValueKey('trainer-group-name')),
      'Nueva convocatoria',
    );
    await tap(tester, find.text('Ana').last);
    await tap(tester, find.text('Guardar grupo'));
    expect(repo.saved.length, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('trainer-group-name')))
          .enabled,
      isFalse,
    );
    repo.failGroup = false;
    await tap(tester, find.text('Reintentar mismo grupo'));
    expect(repo.saved.length, 2);
    expect(repo.saved[0].op, repo.saved[1].op);
    expect(repo.saved[0].id, repo.saved[1].id);
    expect(repo.saved[0].name, repo.saved[1].name);
    expect(repo.saved[0].clients, repo.saved[1].clients);
    expect(repo.saved.first.name, 'Nueva convocatoria');
  });
  testWidgets(
    'tanda exige preview y conserva payload tras respuesta incierta',
    (tester) async {
      final repo = GroupsFixture()..failBatch = true;
      await tester.pumpWidget(openBatch(repo));
      await tap(tester, find.text('Abrir envío'));
      expect(repo.sent, isEmpty);
      await prepareSession(tester);
      expect(repo.prepared.single.groupRevision, 3);
      expect(find.textContaining('Coincide con otras pautas'), findsOneWidget);
      await tap(tester, find.text('Confirmar 2 citas'));
      expect(find.text('Cambiar selección'), findsNothing);
      repo.failBatch = false;
      await tap(tester, find.text('Reintentar misma tanda'));
      expect(repo.sent.length, 2);
      expect(repo.sent[0].op, repo.sent[1].op);
      expect(repo.sent[0].params, repo.sent[1].params);
      expect(repo.sent.first.params['p_fingerprint'], 'batch-1');
      expect(find.text('Ana: 1 cita confirmada.'), findsOneWidget);
      expect(find.text('Luis: 1 cita confirmada.'), findsOneWidget);
    },
  );
  testWidgets('tanda obsoleta exige nueva revisión y nueva orden', (
    tester,
  ) async {
    final repo = GroupsFixture()..staleBatch = true;
    await tester.pumpWidget(openBatch(repo));
    await tap(tester, find.text('Abrir envío'));
    await prepareSession(tester);
    await tap(tester, find.text('Confirmar 2 citas'));
    expect(find.textContaining('La planificación ha cambiado'), findsOneWidget);
    expect(find.text('Reintentar misma tanda'), findsNothing);
    repo.staleBatch = false;
    await tap(tester, find.text('Revisar destinatarios y fechas'));
    await tap(tester, find.text('Confirmar 2 citas'));
    expect(repo.sent.length, 2);
    expect(repo.sent.first.op, isNot(repo.sent.last.op));
    expect(repo.sent.first.params['p_fingerprint'], 'batch-1');
    expect(repo.sent.last.params['p_fingerprint'], 'batch-2');
  });
  testWidgets('programa requiere fechas explícitas sin repetir por duración', (
    tester,
  ) async {
    final repo = GroupsFixture();
    await tester.pumpWidget(openBatch(repo));
    await tap(tester, find.text('Abrir envío'));
    await tap(tester, find.text('Programa'));
    await tap(tester, find.byKey(const ValueKey('trainer-batch-program')));
    await tester.tap(find.text('Preparación de dominadas · v2').last);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Revisar destinatarios y fechas'));
    expect(repo.prepared, isEmpty);
    await tap(
      tester,
      find.byKey(const ValueKey('trainer-batch-phase-program-0')),
    );
    await tester.tap(find.text('Todas las fases').last);
    await tester.pumpAndSettle();
    await chooseDate(
      tester,
      find.byKey(const ValueKey('trainer-batch-program-date-0-0')),
    );
    await chooseDate(
      tester,
      find.byKey(const ValueKey('trainer-batch-program-date-1-0')),
    );
    await tap(tester, find.text('Revisar destinatarios y fechas'));
    expect(repo.prepared.single.entries.length, 2);
    expect(repo.prepared.single.programId, 'program');
    expect(repo.prepared.single.templateId, isNull);
    expect(find.text('Confirmar 4 citas'), findsOneWidget);
  });
  testWidgets('grupo con vínculo inactivo no se envía por defecto', (
    tester,
  ) async {
    final repo = GroupsFixture()..rows = [group(inactive: true)];
    await tester.pumpWidget(
      app(
        TrainerGroupsPage(
          repository: repo,
          access: access(),
          workouts: WorkoutFixture(),
          programs: ProgramFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Preparar envío al grupo'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('alumnos inactivos'), findsOneWidget);
  });
  testWidgets('copia conserva huella y UUID al reintentar y muestra recibos', (
    tester,
  ) async {
    final repo = GroupsFixture()..failCopy = true;
    await tester.pumpWidget(openCopy(repo));
    await tap(tester, find.text('Abrir copia'));
    expect(find.textContaining('1 excluidas'), findsOneWidget);
    expect(
      find.textContaining('Coincide con otra pauta en la fecha destino'),
      findsOneWidget,
    );
    await tap(tester, find.text('Confirmar 2 pautas'));
    repo.failCopy = false;
    await tap(tester, find.text('Reintentar misma copia'));
    expect(repo.previewCount, 1);
    expect(repo.copies.length, 2);
    expect(repo.copies[0], repo.copies[1]);
    expect(find.text('Ana: 1 pauta añadida.'), findsOneWidget);
    expect(find.text('Luis: 1 pauta añadida.'), findsOneWidget);
  });
  testWidgets('copia obsoleta exige volver a revisar y genera nueva orden', (
    tester,
  ) async {
    final repo = GroupsFixture()..staleCopy = true;
    await tester.pumpWidget(openCopy(repo));
    await tap(tester, find.text('Abrir copia'));
    await tap(tester, find.text('Confirmar 2 pautas'));
    expect(find.text('Reintentar misma copia'), findsNothing);
    repo.staleCopy = false;
    await tap(tester, find.text('Volver a revisar'));
    await tap(tester, find.text('Confirmar 2 pautas'));
    expect(repo.copies[0].fingerprint, 'fingerprint-1');
    expect(repo.copies[1].fingerprint, 'fingerprint-2');
    expect(repo.copies[0].op, isNot(repo.copies[1].op));
  });
  testWidgets('copia vacía explica exclusiones sin confirmar', (tester) async {
    final repo = GroupsFixture()
      ..copySize = 0
      ..excluded = 3;
    await tester.pumpWidget(openCopy(repo));
    await tap(tester, find.text('Abrir copia'));
    expect(find.textContaining('3 excluidas'), findsOneWidget);
    expect(find.textContaining('No hay pautas pendientes'), findsOneWidget);
    expect(repo.copies, isEmpty);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('grupos envío y copia caben a $width con texto doble', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = GroupsFixture();
      await tester.pumpWidget(
        app(
          TrainerGroupsPage(
            repository: repo,
            access: access(),
            workouts: WorkoutFixture(),
            programs: ProgramFixture(),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Preparar envío al grupo'));
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Cerrar'));
      await tester.pumpWidget(openCopy(repo, scale: 2));
      await tap(tester, find.text('Abrir copia'));
      expect(tester.takeException(), isNull);
      await tap(tester, find.text('Ver receta fijada').first);
      expect(find.textContaining('Dominadas'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
