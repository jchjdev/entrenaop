import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';

import 'trainer_workout_result_groups_test.dart'
    show series, resultApp, showResultDetails;

void main() {
  testWidgets(
    'filtro profesional opcional oculta solo coincidencias y mantiene omisiones',
    (tester) async {
      final sets = [
        series(0),
        series(1, reps: 4),
        series(2, status: 'skipped'),
      ];
      await tester.pumpWidget(resultApp(sets));
      await tester.pumpAndSettle();
      await showResultDetails(tester);
      expect(find.text('2/3 completadas · 1 omitida'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Solo diferencias con la pauta'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Solo diferencias con la pauta'));
      await tester.pumpAndSettle();
      await showResultDetails(tester);
      expect(find.text('1/2 completadas · 1 omitida'), findsOneWidget);
      await tester.ensureVisible(find.text('Press banca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();
      expect(find.text('Serie 1 · Completada'), findsNothing);
      expect(find.text('Serie 2 · Completada'), findsOneWidget);
      expect(find.text('Serie 3 · Omitida'), findsOneWidget);
      expect(find.byTooltip('Corregir resultado'), findsNothing);
    },
  );
  test(
    'consulta anterior profesional usa solo pautas del alumno y misma versión',
    () async {
      final repo = _ReviewRepository();
      final page = await loadTrainerComparisonPage(repo, {
        'user_id': 'client',
        'id': 'now',
        'template_id': 'template',
        'template_version': 1,
        'started_at': '2026-10-24T10:00:00Z',
        'status': 'completed',
      }, null);
      expect(repo.clients, ['client']);
      expect(repo.results, ['old']);
      expect(page.sessions.single.id, 'old-execution');
      expect(page.nextCursor, isNull);
    },
  );
  test('no deduce la cuenta si falta identidad', () async {
    final repo = _ReviewRepository();
    await expectLater(
      loadTrainerComparisonPage(repo, {}, null),
      throwsStateError,
    );
    expect(repo.clients, isEmpty);
  });
}

class _ReviewRepository implements TrainerWorkoutRepository {
  final clients = <String>[], results = <String>[];
  @override
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
    TrainerAssignmentVisibility visibility = TrainerAssignmentVisibility.all,
  }) async {
    clients.add(clientId);
    return [
      for (final id in ['old', 'other'])
        TrainerAssignment.fromJson({
          'id': id,
          'template_id': id == 'old' ? 'template' : 'another',
          'template_name': 'Fuerza',
          'template_version': 1,
          'scheduled_date': '2026-10-23',
          'created_at': '2026-10-22T00:00:00Z',
          'status': 'completed',
          'execution_id': '$id-execution',
        }),
    ];
  }

  @override
  Future<WorkoutJson?> result(String assignmentId) async {
    results.add(assignmentId);
    return {
      'user_id': 'client',
      'id': 'old-execution',
      'template_id': 'template',
      'template_version': 1,
      'started_at': '2026-10-23T10:00:00Z',
      'status': 'completed',
      'workout_execution_sets': [series(0)],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
