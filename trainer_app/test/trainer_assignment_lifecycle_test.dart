import 'package:entrenaop_trainer/trainer_assignment_lifecycle_actions.dart';
import 'package:entrenaop_trainer/trainer_client_planning_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trainer_client_planning_test.dart' as planning;
import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;
import 'trainer_exercise_repository_test.dart' show owner;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

Map<String, dynamic> archivedRow({
  bool archived = false,
  String? reason,
  String? execution,
}) => {
  'id': '0',
  'template_id': 'template',
  'template_name': 'Sesión retirada',
  'template_version': 1,
  'scheduled_date': '2026-10-26',
  'created_at': '2026-10-25T10:00:00Z',
  'status': 'cancelled',
  'archive_revision': archived ? 1 : 0,
  'archived_at': archived ? '2026-10-25T10:00:00Z' : null,
  'delete_block_reason': reason,
  'execution_id': execution,
};

class LifecycleFixture extends WorkoutFixture {
  final calls = <({String id, TrainerAssignmentLifecycleAction action})>[];
  bool fail = false;
  @override
  Future<void> changeLifecycle({
    required String operationId,
    required TrainerAssignment assignment,
    required TrainerAssignmentLifecycleAction action,
  }) async {
    calls.add((id: operationId, action: action));
    if (fail) throw StateError('Sin conexión');
  }
}

class ArchivedPlanning extends planning.PlanningFixture {
  @override
  Future<TrainerClientAgendaPage> week(
    String clientId,
    DateTime from,
    DateTime to, {
    TrainerClientAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async => TrainerClientAgendaPage(
    items:
        visibility == TrainerAssignmentVisibility.archived ||
            visibility == TrainerAssignmentVisibility.all
        ? [
            TrainerClientAgendaItem.fromJson({
              ...archivedRow(archived: true),
              'is_running': false,
            }),
          ]
        : [],
    hasMore: false,
  );
}

Future<void> showActions(
  WidgetTester t,
  LifecycleFixture repo, {
  String? reason,
  bool archived = false,
  double width = 600,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrainerAssignmentLifecycleActions(
            assignment: TrainerAssignment.fromJson(
              archivedRow(archived: archived, reason: reason),
            ),
            repository: repo,
            onChanged: () async {},
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test(
    'la retirada confirmada desbloquea según servidor sin saltarse resultados',
    () {
      final allowed = TrainerAssignment.fromJson(archivedRow());
      expect(allowed.deletionExplanation, isNull);
      final pending = TrainerAssignment.fromJson(archivedRow(reason: 'garmin'));
      expect(pending.deletionExplanation, contains('retirada confirmada'));
      final withResults = TrainerAssignment.fromJson(
        archivedRow(execution: 'execution'),
      );
      expect(withResults.deletionExplanation, contains('resultados'));
    },
  );

  testWidgets(
    'la compartición no reintroduce una archivada y el filtro la recupera',
    (t) async {
      await planning.mount(t, planning: ArchivedPlanning());
      expect(
        find.byKey(const ValueKey('client-planning-entry-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('assignment-filter-archived')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('client-planning-entry-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('client-planning-entry-0')));
      await t.pumpAndSettle();
      expect(find.text('Restaurar en calendario'), findsOneWidget);
    },
  );
  testWidgets(
    'borrado exige confirmar y un fallo conserva la identidad del reintento',
    (t) async {
      final repo = LifecycleFixture()..fail = true;
      await showActions(t, repo);
      await t.tap(find.text('Borrar definitivamente'));
      await t.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await t.tap(find.text('Conservar'));
      await t.pumpAndSettle();
      expect(repo.calls, isEmpty);
      await t.tap(find.text('Borrar definitivamente'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Borrar definitivamente'));
      await t.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      repo.fail = false;
      await t.tap(find.text('Borrar definitivamente'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Borrar definitivamente'));
      await t.pumpAndSettle();
      expect(repo.calls, hasLength(2));
      expect(repo.calls.first.id, repo.calls.last.id);
    },
  );
  for (final reason in ['garmin', 'results', 'references']) {
    testWidgets(
      '$reason bloquea borrar pero permite archivar a 320px y texto doble',
      (t) async {
        final repo = LifecycleFixture();
        await showActions(t, repo, reason: reason, width: 320, scale: 2);
        final button = t.widget<TextButton>(
          find.widgetWithText(TextButton, 'Borrar definitivamente'),
        );
        expect(button.onPressed, isNull);
        await t.tap(find.text('Archivar sesión'));
        await t.pumpAndSettle();
        expect(
          repo.calls.single.action,
          TrainerAssignmentLifecycleAction.archive,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  test('las fachadas fijan cuenta, revisión, acción y filtro', () async {
    final server = ProgramWorkServer();
    addTearDown(server.client.dispose);
    await server.login();
    server.respond = (request, name, params) async => server.json(
      request,
      name == 'list_trainer_assignments_filtered' ? [] : {'deleted': true},
    );
    final repo = SupabaseTrainerWorkoutRepository(server.client, owner);
    await repo.changeLifecycle(
      operationId: 'operation',
      assignment: TrainerAssignment.fromJson(archivedRow(archived: true)),
      action: TrainerAssignmentLifecycleAction.delete,
    );
    expect(server.calls.last.name, 'change_trainer_assignment_lifecycle');
    expect(server.calls.last.params, {
      'p_expected_owner': owner,
      'p_operation_id': 'operation',
      'p_id': '0',
      'p_revision': 1,
      'p_action': 'delete',
    });
    await repo.assignments(
      'student',
      visibility: TrainerAssignmentVisibility.archived,
    );
    expect(server.calls.last.name, 'list_trainer_assignments_filtered');
    expect(server.calls.last.params['p_visibility'], 'archived');
  });
}
