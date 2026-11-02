import 'dart:async';

import 'package:entrenaop/features/coach_workspace/presentation/coach_assignment_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:workout_core/workout_template.dart';

import '../../support/coach_planning_fixture.dart';
import '../../support/coach_workspace_fixture.dart';
import 'coach_planning_flow_test.dart' show mount, tapText;

Map<String, Object> row(
  String id,
  DateTime day, {
  bool own = false,
  String source = 'coach',
  String status = 'planned',
}) => {
  'id': id,
  'scheduled_date': day.toIso8601String(),
  'template_name': id,
  'source': source,
  'status': status,
  'is_own': own,
  'trainer_name': 'Ervi',
  'is_running': true,
};
SharedCalendarPage page(List<Map<String, Object>> rows, {bool more = false}) =>
    SharedCalendarPage.fromJson({
      'shared': true,
      'has_more': more,
      'coaches': [],
      'items': rows,
    });

class ReceivedAgenda extends FakeCoach {
  final calls = <(String, DateTime, DateTime, String?)>[];
  final workoutReads = <String>[];
  bool failWorkout = false;
  @override
  Future<WorkoutTemplate> receivedWorkout(String scheduledId) async {
    workoutReads.add(scheduledId);
    if (failWorkout) throw StateError('No disponible');
    return const WorkoutTemplate(
      id: 'version-recibida',
      name: '10X400 REC 45 SEG',
      description: 'Calienta antes de empezar las series.',
      estimatedDurationMinutes: 40,
      version: 3,
      blocks: [
        WorkoutBlock(
          id: 'block',
          name: 'Series pautadas',
          format: WorkoutBlockFormat.running,
          rounds: 1,
          restAfterSeconds: 0,
          items: [
            WorkoutItem(
              id: 'item',
              exerciseId: 'running',
              exerciseName: 'Carrera',
              sets: [
                WorkoutSet(
                  id: 'set',
                  order: 1,
                  targetDistanceMeters: 400,
                  restAfterSeconds: 45,
                  recoveryType: RunningRecoveryType.passive,
                  recoveryDurationSeconds: 45,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<SharedCalendarPage> Function(int, DateTime)? answer;
  @override
  Future<SharedCalendarPage> sharedCalendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) {
    calls.add((clientId, from, to, after?.id));
    return answer?.call(calls.length, from) ??
        Future.value(
          page([
            row('Serie recibida', from),
            row('Mi pauta duplicada', from, own: true),
            row('Plan automático', from, source: 'user'),
            row('Retirada ajena', from, status: 'cancelled'),
          ]),
        );
  }
}

void main() {
  testWidgets(
    'la agenda muestra lo recibido para mí, con autor y sin acciones de edición',
    (t) async {
      final repo = ReceivedAgenda();
      final router = await mount(
        t,
        FakeCoachPlanning(),
        '/coach/agenda',
        coach: repo,
      );
      await t.ensureVisible(find.text('Serie recibida'));
      expect(find.text('Para mí · Ervi'), findsOneWidget);
      expect(find.text('Pendiente · Solo consulta'), findsOneWidget);
      expect(find.text('Mi pauta duplicada'), findsNothing);
      expect(find.text('Plan automático'), findsNothing);
      expect(find.text('Retirada ajena'), findsNothing);
      expect(find.byType(CoachAssignmentActions), findsNothing);
      expect(repo.calls.single.$1, 'self');
      expect(repo.calls.single.$3.difference(repo.calls.single.$2).inDays, 6);
      await tapText(t, 'Serie recibida');
      expect(router.canPop(), isTrue);
      expect(repo.workoutReads, ['Serie recibida']);
      expect(find.text('Entrenamiento pautado'), findsOneWidget);
      expect(find.text('10X400 REC 45 SEG'), findsOneWidget);
      expect(find.textContaining('400 m'), findsOneWidget);
      expect(find.textContaining('0:45'), findsOneWidget);
      expect(find.byType(CoachAssignmentActions), findsNothing);
      for (final action in [
        'Adaptar',
        'Retirar',
        'Asignar sesión',
        'Comenzar',
      ]) {
        expect(find.text(action), findsNothing);
      }
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Serie recibida'), findsOneWidget);
      expect(repo.calls, hasLength(1));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pagina por la página completa aunque la primera contenga solo pautas propias',
    (t) async {
      final repo = ReceivedAgenda()
        ..answer = (n, from) async => n == 1
            ? page([row('propia-cursor', from, own: true)], more: true)
            : page([row('Recibida página dos', from)]);
      await mount(t, FakeCoachPlanning(), '/coach/agenda', coach: repo);
      await tapText(t, 'Cargar más de mi preparador');
      expect(repo.calls.last.$4, 'propia-cursor');
      expect(repo.calls.last.$1, 'self');
      await t.ensureVisible(find.text('Recibida página dos'));
      expect(find.text('Para mí · Ervi'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'un resultado lento de la semana anterior no entra en la siguiente',
    (t) async {
      final pending = Completer<SharedCalendarPage>();
      final repo = ReceivedAgenda()
        ..answer = (n, from) => n == 1
            ? pending.future
            : Future.value(page([row('Semana nueva', from)]));
      final router = createRouter(
        repo,
        FakeSecurity(),
        planning: FakeCoachPlanning(),
        initial: '/coach/agenda',
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byTooltip('Siguiente'));
      await t.pump();
      pending.complete(page([row('Semana antigua', repo.calls.first.$2)]));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Semana nueva'));
      expect(find.text('Semana antigua'), findsNothing);
      expect(repo.calls.last.$2.difference(repo.calls.first.$2).inDays, 7);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'la pauta recibida permite reintentar sin abrir acciones de autor',
    (t) async {
      final repo = ReceivedAgenda()..failWorkout = true;
      final router = await mount(
        t,
        FakeCoachPlanning(),
        '/coach/agenda/received/pauta',
        coach: repo,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('10X400 REC 45 SEG'), findsNothing);
      repo.failWorkout = false;
      await tapText(t, 'Reintentar');
      expect(repo.workoutReads, ['pauta', 'pauta']);
      expect(find.text('10X400 REC 45 SEG'), findsOneWidget);
      expect(find.byType(CoachAssignmentActions), findsNothing);
      router.go('/coach/agenda/received/otra-pauta');
      await t.pumpAndSettle();
      expect(repo.workoutReads, ['pauta', 'pauta', 'otra-pauta']);
      expect(t.takeException(), isNull);
    },
  );
}
