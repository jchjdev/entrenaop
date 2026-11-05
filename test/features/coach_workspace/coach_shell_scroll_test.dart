import 'dart:math';

import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_planning_agenda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../support/coach_workspace_fixture.dart';

void main() {
  for (final (label, path) in [
    ('Resumen', '/coach'),
    ('Agenda', '/coach/agenda'),
    ('Alumnos', '/coach/clients'),
    ('Mensajes', '/coach/messages'),
  ]) {
    testWidgets('$label sube al repetir el destino y conserva su consulta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _LongCoach();
      final router = createRouter(repository, FakeSecurity(), initial: path);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (label == 'Alumnos' || label == 'Mensajes') {
        await tester.tap(find.text('Inactivos'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Usuario');
        await tester.pumpAndSettle();
      }
      final position = _verticalPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(min(360, position.maxScrollExtent));
      await tester.pumpAndSettle();
      final reads = repository.reads;
      await _tapDestination(tester, label);
      await tester.pumpAndSettle();
      expect(_verticalPosition(tester).pixels, closeTo(0, .1));
      expect(router.state.uri.path, path);
      expect(repository.reads, reads);
      if (label == 'Alumnos' || label == 'Mensajes') {
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Inactivos'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Usuario',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cambiar entre Alumnos y Mensajes recupera sus posiciones', (
    tester,
  ) async {
    final router = createRouter(
      _LongCoach(),
      FakeSecurity(),
      initial: '/coach/clients',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    _verticalPosition(tester).jumpTo(400);
    await tester.pumpAndSettle();
    await _tapDestination(tester, 'Mensajes');
    await tester.pumpAndSettle();
    _verticalPosition(tester).jumpTo(650);
    await tester.pumpAndSettle();
    await _tapDestination(tester, 'Alumnos');
    await tester.pumpAndSettle();
    expect(_verticalPosition(tester).pixels, closeTo(400, .1));
    await _tapDestination(tester, 'Alumnos');
    await tester.pumpAndSettle();
    expect(_verticalPosition(tester).pixels, closeTo(0, .1));
    await _tapDestination(tester, 'Mensajes');
    await tester.pumpAndSettle();
    expect(_verticalPosition(tester).pixels, closeTo(650, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Agenda conserva fecha y vista al subir al principio', (
    tester,
  ) async {
    final router = createRouter(
      _LongCoach(),
      FakeSecurity(),
      initial: '/coach/agenda',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CoachPlanningAgendaPage));
    _verticalPosition(tester).jumpTo(300);
    await tester.pumpAndSettle();
    await _tapDestination(tester, 'Agenda');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(CoachPlanningAgendaPage)), same(state));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mes'))
          .selected,
      isTrue,
    );
    expect(_verticalPosition(tester).pixels, closeTo(0, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde la ficha vuelve a Alumnos y deja la portada arriba', (
    tester,
  ) async {
    final router = createRouter(
      _LongCoach(),
      FakeSecurity(),
      initial: '/coach/clients',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    _verticalPosition(tester).jumpTo(450);
    await tester.pumpAndSettle();
    router.push('/coach/clients/client-0');
    await tester.pumpAndSettle();
    await _tapDestination(tester, 'Alumnos');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/coach/clients');
    expect(_verticalPosition(tester).pixels, closeTo(0, .1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapDestination(WidgetTester tester, String label) =>
    tester.tap(find.widgetWithText(NavigationDestination, label));

ScrollPosition _verticalPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .hitTestable(),
    )
    .position;

class _LongCoach extends FakeCoach {
  int reads = 0;

  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) async {
    reads++;
    return List.generate(
      40,
      (index) => TrainerClient.fromJson({
        'person_id': 'client-$index',
        'person_name': 'Usuario $index',
        'created_at': '2026-10-20T00:00:00Z',
        'updated_at': '2026-10-20T00:00:00Z',
        'accepted_at': '2026-10-20T00:00:00Z',
        'active_relation_id': 'relation-$index',
        'episode_count': 1,
      }),
    );
  }

  @override
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  }) async {
    reads++;
    return List.generate(
      20,
      (index) => CoachAssignment(
        id: 'assignment-$index',
        name: 'Sesión $index',
        date: from,
        clientId: 'client-$index',
        clientName: 'Usuario $index',
        status: 'planned',
        createdAt: from,
      ),
    );
  }
}
