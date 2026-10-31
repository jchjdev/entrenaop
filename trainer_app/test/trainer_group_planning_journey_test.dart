import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_groups_page.dart';
import 'package:entrenaop_trainer/trainer_program_date_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/helpers/performance_visual_review.dart';

import 'trainer_groups_flow_test.dart' as groups;
import 'trainer_program_flow_test.dart' show ProgramFixture, privateProgram;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

Future<void> chooseProgram(WidgetTester t) async {
  await groups.tap(t, find.text('Programa'));
  await groups.tap(t, find.byKey(const ValueKey('trainer-batch-program')));
  await t.tap(find.text('Preparación de dominadas · v2').last);
  await t.pumpAndSettle();
  await groups.tap(
    t,
    find.byKey(const ValueKey('trainer-batch-phase-program-0')),
  );
  await t.tap(find.text('Todas las fases').last);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFont);
  testWidgets('revisión y recibo por alumno caben a 320 con texto doble', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = groups.GroupsFixture();
    final opened = <String>[];
    await t.pumpWidget(
      groups.app(
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TrainerBatchAssignmentDialog(
                  repository: repo,
                  access: groups.access(),
                  workouts: WorkoutFixture(),
                  programs: ProgramFixture(),
                  group: groups.group(),
                  onOpenClient: (client, _) => opened.add(client),
                ),
              ),
              child: const Text('Abrir envío'),
            ),
          ),
        ),
        scale: 2,
      ),
    );
    await groups.tap(t, find.text('Abrir envío'));
    await groups.prepareSession(t);
    expect(t.takeException(), isNull);
    await groups.tap(t, find.text('Confirmar 2 citas'));
    expect(t.takeException(), isNull);
    await groups.tap(t, find.byKey(const ValueKey('trainer-batch-open-luis')));
    expect(opened, ['luis']);
    expect(repo.sent, hasLength(1));
    expect(t.takeException(), isNull);
  });

  test('propuesta única conserva fases y días civiles al cruzar mes y cambio horario', () {
    final dates = proposeTrainerProgramDates(
      privateProgram,
      -1,
      DateTime(2026, 10, 31, 23),
    );
    expect(dates.map((e) => (e.phase, e.session, e.date)), [
      (0, 0, DateTime(2026, 10, 31)),
      (1, 0, DateTime(2026, 11, 2)),
    ]);
    final selected = proposeTrainerProgramDates(
      privateProgram,
      1,
      DateTime(2026, 3, 28),
    );
    expect(selected, hasLength(1));
    expect(selected.single.phase, 1);
    expect(selected.single.date, DateTime(2026, 3, 28));
    expect(privateProgram.phases.map((phase) => phase.durationWeeks), [2, 3]);
  });

  test('enlace abre una fecha canónica y rechaza fechas normalizadas o fuera de rango', () {
    expect(
      trainerClientPlanningLocation('ana', DateTime(2026, 11, 2)),
      '/clients/ana/workouts?date=2026-11-02',
    );
    expect(parseTrainerPlanningDate('2026-11-02'), DateTime(2026, 11, 2));
    for (final invalid in [
      null,
      '',
      '2026-02-31',
      '2026-13-01',
      '2026-1-1',
      '1969-12-31',
      '2201-01-01',
      '2026-11-02T00:00:00Z',
    ]) {
      expect(parseTrainerPlanningDate(invalid), isNull, reason: '$invalid');
    }
  });

  testWidgets(
    'programa propone fechas, revisa recetas y entrega una sola tanda',
    (t) async {
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = groups.GroupsFixture();
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: groups.openBatch(repo),
        ),
      );
      await groups.tap(t, find.text('Abrir envío'));
      await chooseProgram(t);
      await groups.chooseDate(
        t,
        find.byKey(const ValueKey('trainer-batch-propose-dates')),
      );
      expect(repo.sent, isEmpty);
      await groups.tap(t, find.text('Revisar destinatarios y fechas'));
      expect(
        find
            .text('Planificación común que recibirá cada alumno:')
            .hitTestable(),
        findsOneWidget,
      );
      final request = repo.prepared.single;
      expect(request.entries, hasLength(2));
      final first = request.entries.first.date;
      expect(
        request.entries.last.date,
        DateTime(first.year, first.month, first.day + 2),
      );
      expect(find.textContaining(' · Fuerza A'), findsOneWidget);
      expect(find.textContaining(' · Fuerza B'), findsOneWidget);
      await groups.tap(t, find.byTooltip('Ver receta de Fuerza A'));
      await groups.tap(t, find.text('Volver al envío'));
      await capturePerformanceWidget(t, 'trainer-group-program-preview');
      expect(
        find.text('Alumnos con coincidencias de fecha: 1.'),
        findsOneWidget,
      );
      expect(repo.sent, isEmpty);
      await groups.tap(t, find.text('Confirmar 4 citas'));
      expect(repo.sent, hasLength(1));
      expect(
        repo.sent.single.params['p_entries'],
        request.entries.map((entry) => entry.toJson()).toList(),
      );
      expect(find.text('Ana: 2 citas confirmadas.'), findsOneWidget);
      expect(find.text('Luis: 2 citas confirmadas.'), findsOneWidget);
      await capturePerformanceWidget(t, 'trainer-group-program-receipt');
    },
  );

  testWidgets('cancelar una nueva propuesta conserva las fechas ya elegidas', (
    t,
  ) async {
    final repo = groups.GroupsFixture();
    await t.pumpWidget(groups.openBatch(repo));
    await groups.tap(t, find.text('Abrir envío'));
    await chooseProgram(t);
    await groups.chooseDate(
      t,
      find.byKey(const ValueKey('trainer-batch-propose-dates')),
    );
    await groups.tap(
      t,
      find.byKey(const ValueKey('trainer-batch-propose-dates')),
    );
    final picker = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    final changedDay = picker.initialDate!.day == 1 ? '2' : '1';
    await t.tap(find.text(changedDay).last);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await groups.tap(t, find.text('Conservar fechas'));
    await groups.tap(t, find.text('Revisar destinatarios y fechas'));
    expect(
      repo.prepared.single.entries.first.date.day,
      picker.initialDate!.day,
    );
    expect(repo.sent, isEmpty);
  });

  testWidgets(
    'recibo permanece al visitar dos alumnos sin repetir la entrega',
    (t) async {
      final repo = groups.GroupsFixture();
      final opened = <(String, DateTime?)>[];
      final router = GoRouter(
        initialLocation: '/groups',
        routes: [
          GoRoute(
            path: '/groups',
            builder: (_, _) => TrainerGroupsPage(
              repository: repo,
              access: groups.access(),
              workouts: WorkoutFixture(),
              programs: ProgramFixture(),
            ),
          ),
          GoRoute(
            path: '/clients/:id/workouts',
            builder: (context, state) {
              opened.add((
                state.pathParameters['id']!,
                parseTrainerPlanningDate(state.uri.queryParameters['date']),
              ));
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver al envío'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
      await groups.tap(t, find.text('Preparar envío al grupo'));
      await groups.prepareSession(t);
      final date = repo.prepared.single.date;
      await groups.tap(t, find.text('Confirmar 2 citas'));
      await capturePerformanceWidget(t, 'trainer-group-recipient-actions');
      for (final client in ['ana', 'luis']) {
        await groups.tap(t, find.byKey(ValueKey('trainer-batch-open-$client')));
        expect(opened.last, (client, date));
        await groups.tap(t, find.text('Volver al envío'));
        expect(find.text('Entrega confirmada'), findsOneWidget);
      }
      expect(repo.sent, hasLength(1));
      await groups.tap(t, find.text('Terminar'));
      expect(find.text('Grupos y envíos'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
