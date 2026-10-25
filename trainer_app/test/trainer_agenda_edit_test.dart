import 'package:entrenaop_trainer/trainer_workout_repository.dart';

import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrainerAgendaItem item(
  String id, {
  String pupil = 'ana',
  String status = 'planned',
  int day = 21,
  String? execution,
}) => TrainerAgendaItem.fromJson({
  'id': id,
  'template_id': 'template',
  'template_name': 'Sesión $id',
  'template_version': 1,
  'scheduled_date': '2026-10-${day.toString().padLeft(2, '0')}',
  'created_at': '2026-10-21T10:00:00Z',
  'status': status,
  'execution_id': execution,
  'note': null,
  'client_id': pupil,
  'client_name': pupil == 'ana' ? 'Ana de prueba' : 'Luis de prueba',
});

class AgendaEditFixture implements TrainerAgendaRepository {
  List<TrainerAgendaItem> rows = [item('one')];
  final calls = <({DateTime from, DateTime to, String? after})>[];
  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    calls.add((from: from, to: to, after: after?.assignment.id));
    return rows
        .where(
          (row) =>
              !row.assignment.date.isBefore(from) &&
              !row.assignment.date.isAfter(to),
        )
        .toList();
  }
}

Widget app(TrainerAgendaPage page, {double scale = 1}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterMove(
  WidgetTester tester, {
  String date = '2026-10-22',
}) async {
  await tapVisible(tester, find.byKey(const ValueKey('agenda-move-one')));
  await tester.enterText(find.byKey(const ValueKey('agenda-date-input')), date);
  await tester.tap(find.text('Proponer movimiento'));
  await tester.pump();
}

void main() {
  testWidgets('callbacks ausentes mantienen la agenda de lectura', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: AgendaEditFixture(),
          now: DateTime(2026, 10, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-move-one')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-adapt-one')), findsNothing);
    expect(find.text('Copiar semana'), findsNothing);
  });

  testWidgets('mover llama una vez y espera servidor antes de recargar', (
    tester,
  ) async {
    final repo = AgendaEditFixture();
    final completion = Completer<void>();
    final moves = <DateTime>[];
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: repo,
          now: DateTime(2026, 10, 21),
          onMove: (assignment, date) async {
            moves.add(date);
            await completion.future;
            repo.rows = [item('one', day: 22)];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterMove(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(moves, [DateTime(2026, 10, 22)]);
    expect(find.text('21/10 · Pendiente · v1'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('agenda-move-one')),
    );
    expect(button.onPressed, isNull);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('22/10 · Pendiente · v1'), findsOneWidget);
    expect(repo.calls.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rechazar movimiento conserva la pauta original', (tester) async {
    final repo = AgendaEditFixture();
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: repo,
          now: DateTime(2026, 10, 21),
          onMove: (_, _) async => throw StateError('Cambio rechazado'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterMove(tester);
    await tester.pumpAndSettle();
    expect(find.text('21/10 · Pendiente · v1'), findsOneWidget);
    expect(
      find.textContaining('No se ha podido confirmar la operación'),
      findsWidgets,
    );
    expect(repo.calls.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fecha inválida y cancelación no invocan movimiento', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: AgendaEditFixture(),
          now: DateTime(2026, 10, 21),
          onMove: (_, _) async {
            calls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('agenda-move-one')));
    await tester.enterText(
      find.byKey(const ValueKey('agenda-date-input')),
      '2026-02-30',
    );
    await tester.tap(find.text('Proponer movimiento'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Introduce una fecha válida'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('21/10 · Pendiente · v1'), findsOneWidget);
  });

  testWidgets('adaptar solo aparece para pendientes sin ejecución', (
    tester,
  ) async {
    final repo = AgendaEditFixture()
      ..rows = [
        item('one'),
        item('started', execution: 'execution'),
        item('done', status: 'completed', execution: 'done'),
      ];
    final adapted = <String>[];
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: repo,
          now: DateTime(2026, 10, 21),
          onAdapt: (assignment) async => adapted.add(assignment.id),
          onMove: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-adapt-started')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-move-started')), findsNothing);
    expect(find.byKey(const ValueKey('agenda-adapt-done')), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('agenda-adapt-one')));
    expect(adapted, ['one']);
  });

  testWidgets('filtros de alumno y estado se combinan', (tester) async {
    final repo = AgendaEditFixture()
      ..rows = [
        item('one'),
        item('luis', pupil: 'luis'),
        item('ana-done', status: 'completed', execution: 'done'),
      ];
    await tester.pumpWidget(
      app(TrainerAgendaPage(repository: repo, now: DateTime(2026, 10, 21))),
    );
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.byKey(const ValueKey('agenda-client-filter')),
    );
    await tester.tap(find.text('Ana de prueba').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-assignment-luis')), findsNothing);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('agenda-status-filter')),
    );
    await tester.tap(find.text('Completada').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-assignment-one')), findsNothing);
    expect(
      find.byKey(const ValueKey('agenda-assignment-ana-done')),
      findsOneWidget,
    );
  });

  testWidgets('semana cruza meses y navega por componentes civiles', (
    tester,
  ) async {
    final repo = AgendaEditFixture();
    await tester.pumpWidget(
      app(TrainerAgendaPage(repository: repo, now: DateTime(2026, 10, 1))),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('agenda-view-week')));
    expect(repo.calls.last.from, DateTime(2026, 9, 28));
    expect(repo.calls.last.to, DateTime(2026, 10, 4));
    await tapVisible(tester, find.byTooltip('Semana siguiente'));
    expect(repo.calls.last.from, DateTime(2026, 10, 5));
    expect(repo.calls.last.to, DateTime(2026, 10, 11));
    await tapVisible(tester, find.byKey(const ValueKey('agenda-view-day')));
    expect(repo.calls.last.from, DateTime(2026, 10, 8));
    expect(repo.calls.last.to, DateTime(2026, 10, 8));
    await tapVisible(tester, find.byKey(const ValueKey('agenda-view-list')));
    expect(repo.calls.last.from, DateTime(2026, 10, 1));
    expect(repo.calls.last.to, DateTime(2026, 10, 31));
  });

  testWidgets('copiar semana avisa alcance y exige lunes destino', (
    tester,
  ) async {
    final copies = <({DateTime from, int offset})>[];
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: AgendaEditFixture(),
          now: DateTime(2026, 10, 21),
          onCopyWeek: (from, offset) async =>
              copies.add((from: from, offset: offset)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Copiar semana'));
    expect(find.textContaining('no solo las cargadas'), findsOneWidget);
    expect(find.textContaining('todos tus alumnos'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('agenda-date-input')),
      '2026-10-28',
    );
    await tester.tap(find.text('Revisar copia de semana'));
    await tester.pumpAndSettle();
    expect(copies, isEmpty);
    expect(find.textContaining('Elige un lunes'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('agenda-date-input')),
      '2026-10-26',
    );
    await tester.tap(find.text('Revisar copia de semana'));
    await tester.pumpAndSettle();
    expect(copies, [(from: DateTime(2026, 10, 19), offset: 7)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrastrar usa la misma propuesta de movimiento', (tester) async {
    final moved = <DateTime>[];
    await tester.pumpWidget(
      app(
        TrainerAgendaPage(
          repository: AgendaEditFixture(),
          now: DateTime(2026, 10, 21),
          onMove: (_, date) async => moved.add(date),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('agenda-view-week')));
    final source = find.byKey(const ValueKey('agenda-drag-one'));
    final target = find.byKey(const ValueKey('agenda-drop-2026-10-22'));
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getTopLeft(source) + const Offset(30, 30),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moved, [DateTime(2026, 10, 22)]);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('vistas y acciones caben a $width con texto doble', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          TrainerAgendaPage(
            repository: AgendaEditFixture(),
            now: DateTime(2026, 10, 21),
            onMove: (_, _) async {},
            onAdapt: (_) async {},
            onCopyWeek: (_, _) async {},
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final view in ['week', 'day', 'list', 'month']) {
        await tapVisible(tester, find.byKey(ValueKey('agenda-view-$view')));
        expect(tester.takeException(), isNull);
      }
      await tapVisible(tester, find.text('Copiar semana'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
