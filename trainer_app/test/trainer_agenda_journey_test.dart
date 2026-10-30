import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_assignment_client_field.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_agenda_session_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../../test/helpers/performance_visual_review.dart';
import 'trainer_agenda_edit_test.dart' as agenda;
import 'trainer_workout_flow_test.dart' show WorkoutFixture, privateRecipe;

class ClientFixture extends FakeTrainerRepository {
  bool fail = false;
  final lookedUp = <String>[];
  @override
  Future<List<TrainerRelation>> clientRelations(
    String id, {
    TrainerRelation? before,
  }) async {
    lookedUp.add(id);
    if (fail) throw StateError('No disponible');
    return super.clientRelations(id, before: before);
  }
}

TrainerAgendaItem session({String status = 'planned', String? execution}) =>
    TrainerAgendaItem.fromJson({
      'id': 'one',
      'template_id': privateRecipe.id,
      'template_name': privateRecipe.name,
      'template_version': privateRecipe.version,
      'scheduled_date': '2026-10-21',
      'created_at': '2026-10-21T10:00:00Z',
      'status': status,
      'execution_id': execution,
      'client_id': 'ana',
      'client_name': 'Ana',
    });

Future<void> mount(
  WidgetTester t,
  Widget child, {
  double width = 1440,
  double scale = 1,
  bool light = false,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? EntrenaTheme.light : EntrenaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: child!,
        ),
      ),
      home: ProfessionalWorkspaceScope(desktop: width >= 900, child: child),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> openEntry(WidgetTester t) => agenda.tapVisible(
  t,
  find.byKey(const ValueKey('agenda-month-event-session-one')),
);

void main() {
  setUpAll(loadReviewFont);

  testWidgets(
    'agenda filtrada confirma alumno, sesión y día sin selección redundante',
    (t) async {
      final repo = agenda.AgendaEditFixture()..rows = [session()];
      final workouts = WorkoutFixture();
      final clients = ClientFixture()
        ..active = [trainerRelation('Ana', personId: 'ana')];
      await mount(
        t,
        TrainerAgendaPage(
          repository: repo,
          access: clients,
          workouts: workouts,
          now: DateTime(2026, 10, 21),
        ),
      );
      t
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('agenda-client-filter')),
          )
          .onChanged!('ana');
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, privateRecipe.name));
      await t.pumpAndSettle();
      expect(find.byType(TrainerAssignmentDialog), findsOneWidget);
      expect(find.text('Elegir alumno para la pauta'), findsNothing);
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.text('Fecha: 21/10/2026'), findsOneWidget);
      expect(clients.lookedUp, ['ana']);
      expect(workouts.libraryReads, 1);
      expect(workouts.assigned, isEmpty);
      final button = find.widgetWithText(FilledButton, 'Asignar sesión');
      await t.tap(button);
      await t.pumpAndSettle();
      expect(workouts.assigned.single.relation, 'relation-a');
      expect(workouts.assigned.single.date, DateTime(2026, 10, 21));
      expect(repo.calls.length, 2);
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('agenda-client-filter')),
            )
            .initialValue,
        'ana',
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('cancelar la asignación no escribe ni recarga la agenda', (
    t,
  ) async {
    final repo = agenda.AgendaEditFixture();
    final workouts = WorkoutFixture();
    await mount(
      t,
      TrainerAgendaPage(
        repository: repo,
        access: FakeTrainerRepository(),
        workouts: workouts,
        now: DateTime(2026, 10, 21),
      ),
    );
    await t.tap(find.widgetWithText(ListTile, privateRecipe.name));
    await t.pumpAndSettle();
    await t.tap(find.text('Volver'));
    await t.pumpAndSettle();
    expect(workouts.assigned, isEmpty);
    expect(repo.calls.length, 1);
    expect(workouts.libraryReads, 1);
  });

  testWidgets(
    'un vínculo terminado no cambia silenciosamente de destinatario',
    (t) async {
      final workouts = WorkoutFixture();
      final clients = ClientFixture()
        ..history = [trainerRelation('Ana', personId: 'ana', ended: true)]
        ..active = [trainerRelation('Luis', personId: 'luis')];
      await mount(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Abrir'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TrainerAssignmentDialog(
                  repository: workouts,
                  accessRepository: clients,
                  initialClientId: 'ana',
                  initialWorkout: workouts.entry,
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('ya no tiene un servicio activo'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Asignar sesión'),
            )
            .onPressed,
        isNull,
      );
      expect(workouts.assigned, isEmpty);
    },
  );

  testWidgets(
    'fallo incierto bloquea el destinatario y reintenta el mismo UUID',
    (t) async {
      final workouts = WorkoutFixture()..failAssign = true;
      final clients = ClientFixture()
        ..active = [trainerRelation('Ana', personId: 'ana')];
      await mount(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Abrir'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TrainerAssignmentDialog(
                  repository: workouts,
                  accessRepository: clients,
                  initialClientId: 'ana',
                  initialWorkout: workouts.entry,
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Asignar sesión'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TrainerAssignmentClientField>(
              find.byType(TrainerAssignmentClientField),
            )
            .enabled,
        isFalse,
      );
      workouts.failAssign = false;
      await t.tap(find.widgetWithText(FilledButton, 'Reintentar asignación'));
      await t.pumpAndSettle();
      expect(workouts.assigned.length, 2);
      expect(workouts.assigned.first.id, workouts.assigned.last.id);
      expect(workouts.assigned.first.relation, workouts.assigned.last.relation);
    },
  );

  testWidgets(
    'panel consulta la versión asignada y resultados sin salir de Agenda',
    (t) async {
      final repo = agenda.AgendaEditFixture()
        ..rows = [session(status: 'completed', execution: 'execution')];
      await mount(
        t,
        TrainerAgendaPage(
          repository: repo,
          workouts: WorkoutFixture(),
          now: DateTime(2026, 10, 21),
        ),
      );
      await openEntry(t);
      expect(
        find.byKey(const ValueKey('agenda-session-panel')),
        findsOneWidget,
      );
      expect(find.text('1. Dominadas'), findsOneWidget);
      await capturePerformanceWidget(t, 'agenda-panel-receta-real');
      await t.tap(find.widgetWithText(ChoiceChip, 'Resultados'));
      await t.pumpAndSettle();
      expect(find.text('Buenas sensaciones'), findsOneWidget);
      await capturePerformanceWidget(t, 'agenda-panel-resultados-real');
      expect(find.text('Mover fecha'), findsNothing);
      await t.tap(find.byTooltip('Cerrar detalle'));
      await t.pumpAndSettle();
      expect(repo.calls.length, 1);
      expect(
        find.byKey(const ValueKey('agenda-month-event-session-one')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'retirar desde el panel reutiliza confirmación y actualiza la agenda',
    (t) async {
      final repo = agenda.AgendaEditFixture()..rows = [session()];
      final workouts = CancelFixture(() => repo.rows = []);
      await mount(
        t,
        TrainerAgendaPage(
          repository: repo,
          workouts: workouts,
          now: DateTime(2026, 10, 21),
        ),
      );
      await openEntry(t);
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('agenda-session-panel')),
          matching: find.text('Retirar sesión'),
        ),
      );
      await t.pumpAndSettle();
      expect(workouts.cancelled, isEmpty);
      await t.tap(find.widgetWithText(FilledButton, 'Retirar sesión'));
      await t.pumpAndSettle();
      expect(workouts.cancelled, ['one']);
      expect(repo.calls.length, 2);
      expect(
        find.byKey(const ValueKey('agenda-month-event-session-one')),
        findsNothing,
      );
    },
  );

  testWidgets('volver de la ficha mantiene semana, filtros y posición', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = agenda.AgendaEditFixture()..rows = [session()];
    final router = GoRouter(
      initialLocation: '/agenda',
      routes: [
        GoRoute(
          path: '/agenda',
          builder: (_, _) => ProfessionalWorkspaceScope(
            desktop: true,
            child: TrainerAgendaPage(
              repository: repo,
              workouts: WorkoutFixture(),
              now: DateTime(2026, 10, 21),
            ),
          ),
        ),
        GoRoute(
          path: '/clients/:id/workouts',
          builder: (context, _) =>
              Scaffold(appBar: AppBar(title: const Text('Ficha de Ana'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await t.pumpAndSettle();
    await agenda.tapVisible(t, find.byKey(const ValueKey('agenda-view-week')));
    t
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('agenda-client-filter')),
        )
        .onChanged!('ana');
    t
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('agenda-status-filter')),
        )
        .onChanged!('planned');
    await t.pumpAndSettle();
    final tile = find.byKey(const ValueKey('agenda-board-entry-one'));
    await agenda.tapVisible(t, tile);
    final scroll = t
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('trainer-agenda-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final offset = scroll.pixels;
    await t.tap(find.text('Planificación del alumno').last);
    await t.pumpAndSettle();
    expect(find.text('Ficha de Ana'), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    expect(scroll.pixels, closeTo(offset, 1));
    expect(repo.calls.last.from, DateTime(2026, 10, 19));
    // Primero se comprueba el retorno; después se sube para leer la cabecera,
    // que no se materializa mientras permanece fuera de la zona visible.
    scroll.jumpTo(0);
    await t.pumpAndSettle();
    expect(find.text('19/10/2026 – 25/10/2026'), findsOneWidget);
    expect(
      t
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('agenda-client-filter')),
          )
          .initialValue,
      'ana',
    );
    expect(
      t
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('agenda-status-filter')),
          )
          .initialValue,
      'planned',
    );
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 1440.0]) {
    for (final light in [false, true]) {
      testWidgets('panel legible a $width, claro=$light, texto doble', (
        t,
      ) async {
        await mount(
          t,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir'),
                onPressed: () => showTrainerAgendaPanel<void>(
                  context,
                  builder: (panel) => TrainerAgendaSessionPanel(
                    name: privateRecipe.name,
                    personName: 'Ana de prueba',
                    metadata: '21/10/2026 · Pendiente · Versión 3',
                    loadRecipe: () async => privateRecipe,
                    repository: WorkoutFixture(),
                    assignmentId: 'one',
                    hasResult: true,
                    actions: (_) => [
                      TextButton(
                        onPressed: () => Navigator.pop(panel),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          width: width,
          scale: 2,
          light: light,
        );
        await t.tap(find.text('Abrir'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (width == 1440) {
          expect(
            t.getTopLeft(find.byKey(const ValueKey('agenda-session-panel'))).dx,
            greaterThan(800),
          );
        }
        await capturePerformanceWidget(
          t,
          'agenda-panel-${width.toInt()}-${light ? "light" : "dark"}',
        );
        await t.tap(find.widgetWithText(ChoiceChip, 'Resultados'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.byTooltip('Cerrar detalle'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agenda-session-panel')),
          findsNothing,
        );
      });
    }
  }

  testWidgets('cerrar durante la carga no deja respuestas en otra selección', (
    t,
  ) async {
    final pending = Completer<WorkoutJson?>();
    final workouts = PendingResultFixture(pending);
    await mount(
      t,
      TrainerAgendaPage(
        repository: agenda.AgendaEditFixture()
          ..rows = [session(execution: 'execution')],
        workouts: workouts,
        now: DateTime(2026, 10, 21),
      ),
    );
    await openEntry(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Resultados'));
    await t.pump();
    await t.tap(find.byTooltip('Cerrar detalle'));
    await t.pumpAndSettle();
    pending.complete(null);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('agenda-session-panel')), findsNothing);
  });
}

class CancelFixture extends WorkoutFixture {
  CancelFixture(this.onCancel);
  final VoidCallback onCancel;
  final cancelled = <String>[];
  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    onCancel();
  }
}

class PendingResultFixture extends WorkoutFixture {
  PendingResultFixture(this.pending);
  final Completer<WorkoutJson?> pending;
  @override
  Future<WorkoutJson?> result(String id) => pending.future;
}
