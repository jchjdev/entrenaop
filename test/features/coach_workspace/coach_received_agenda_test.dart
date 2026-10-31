import 'dart:async';

import 'package:entrenaop/features/coach_workspace/presentation/coach_assignment_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';

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
      await mount(t, FakeCoachPlanning(), '/coach/agenda', coach: repo);
      await tapText(t, 'Serie recibida');
      expect(find.text('Para mí · Ervi'), findsOneWidget);
      expect(find.text('Pendiente · Solo consulta'), findsOneWidget);
      expect(find.text('Mi pauta duplicada'), findsNothing);
      expect(find.text('Plan automático'), findsNothing);
      expect(find.text('Retirada ajena'), findsNothing);
      expect(find.byType(CoachAssignmentActions), findsNothing);
      expect(repo.calls.single.$1, 'self');
      expect(repo.calls.single.$3.difference(repo.calls.single.$2).inDays, 6);
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
      await tapText(t, 'Recibida página dos');
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
      await tapText(t, 'Semana nueva');
      expect(find.text('Semana antigua'), findsNothing);
      expect(repo.calls.last.$2.difference(repo.calls.first.$2).inDays, 7);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
