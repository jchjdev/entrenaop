import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/coach_mobile_fixture.dart';
import '../../support/coach_planning_fixture.dart';
import '../../support/coach_workspace_fixture.dart';

class _Coach extends CoachMobileFixture {
  String status = 'planned';
  String? execution;

  @override
  CoachAssignment sample(String id, {bool completed = false}) =>
      CoachAssignment(
        id: id,
        name: 'Sesión de carrera',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        clientId: 'isabel',
        clientName: 'Isabel',
        status: status,
        executionId: execution,
      );
}

class _Planning extends FakeCoachPlanning {
  _Planning(this.coach);
  final _Coach coach;

  @override
  Future<void> withdraw(String id) async {
    await super.withdraw(id);
    coach.status = 'cancelled';
  }
}

Future<GoRouter> _mount(
  WidgetTester t,
  _Coach coach,
  _Planning planning,
) async {
  final router = createRouter(
    coach,
    FakeSecurity(),
    planning: planning,
    initial: '/coach/agenda',
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await t.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('retirada desde agenda exige confirmar y refresca el estado', (
    t,
  ) async {
    final coach = _Coach();
    final planning = _Planning(coach);
    final router = await _mount(t, coach, planning);
    await t.ensureVisible(find.byTooltip('Opciones de la sesión'));
    await t.tap(find.byTooltip('Opciones de la sesión'));
    await t.pumpAndSettle();
    await t.tap(find.text('Retirar sesión'));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/coach/withdraw/carrera');
    expect(planning.withdrawn, isEmpty);
    await t.tap(find.text('Confirmar retirada'));
    await t.pumpAndSettle();
    expect(planning.withdrawn, ['carrera']);
    expect(router.state.uri.path, '/coach/agenda');
    expect(find.text('Retirada'), findsOneWidget);
    expect(find.byTooltip('Opciones de la sesión'), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final state in ['completed', 'in_progress', 'execution']) {
    testWidgets('agenda protege sesiones con estado $state', (t) async {
      final coach = _Coach()
        ..status = state == 'execution' ? 'planned' : state
        ..execution = state == 'execution' ? 'execution-id' : null;
      final planning = _Planning(coach);
      final router = await _mount(t, coach, planning);
      expect(find.byTooltip('Opciones de la sesión'), findsNothing);
      router.push('/coach/withdraw/carrera');
      await t.pumpAndSettle();
      final confirm = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar retirada'),
      );
      expect(confirm.onPressed, isNull);
      expect(planning.withdrawn, isEmpty);
    });
  }
}
