import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_client_planning_page.dart';
import 'package:entrenaop_trainer/trainer_client_planning_repository.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_client_workspace_test.dart' show WorkspaceFixture;
import 'trainer_shared_calendar_page_test.dart' show CalendarFixture;
import 'trainer_workout_flow_test.dart' show WorkoutFixture, privateRecipe;
import 'trainer_program_flow_test.dart' show ProgramFixture;
import 'trainer_operations_flow_test.dart' show OperationsFixture;

class PlanningFixture extends TrainerClientPlanningRepository {
  final calls = <({String id, DateTime from, DateTime to, String? after})>[];
  Completer<TrainerClientAgendaPage>? pending;
  bool more = false;
  Map<String, dynamic>? deliveryProgress;
  @override
  Future<TrainerClientAgendaPage> week(
    String clientId,
    DateTime from,
    DateTime to, {
    TrainerClientAgendaItem? after,
  }) async {
    calls.add((id: clientId, from: from, to: to, after: after?.assignment.id));
    if (pending != null) return pending!.future;
    return TrainerClientAgendaPage(
      items: [
        TrainerClientAgendaItem.fromJson({
          'id': after == null ? '0' : '2',
          'template_id': 'template',
          'template_name': 'Fuerza propia',
          'template_version': 3,
          'scheduled_date': from.toIso8601String(),
          'status': 'planned',
          'created_at': '2026-10-25T10:00:00Z',
          'note': 'Técnica primero',
          'is_running': false,
          'device_training': deliveryProgress,
        }),
      ],
      hasMore: more && after == null,
    );
  }
}

Future<void> mount(
  WidgetTester t, {
  PlanningFixture? planning,
  CalendarFixture? shared,
  WorkoutFixture? workouts,
  ProgramFixture? programs,
  Future<String?> Function(BuildContext)? createSession,
  Future<String?> Function(BuildContext)? createProgram,
  double width = 1600,
  double scale = 1,
  String client = 'client',
}) async {
  t.view.physicalSize = Size(width, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ProfessionalWorkspaceScope(
        desktop: width >= 900,
        child: TrainerClientPlanningPage(
          clientId: client,
          workspace: WorkspaceFixture(),
          access: FakeTrainerRepository(),
          planning: planning ?? PlanningFixture(),
          sharedCalendar: shared ?? CalendarFixture(),
          workouts: workouts ?? WorkoutFixture(),
          programs: programs ?? ProgramFixture(),
          operations: OperationsFixture(),
          initialDate: DateTime(2026, 10, 26),
          onCreateSession: createSession,
          onCreateProgram: createProgram,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'el estado Garmin solo aparece en la pauta propia y no se confunde cambio con envío',
    (t) async {
      final planning = PlanningFixture()
        ..deliveryProgress = {
          'id': '0',
          'name': 'Fuerza propia',
          'date': '2026-10-28',
          'state': 'change_pending',
          'reason': 'auto_disabled',
        };
      await mount(t, planning: planning);
      await t.tap(find.byKey(const ValueKey('client-planning-entry-0')));
      await t.pumpAndSettle();
      expect(find.text('Cambios pendientes de enviar'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('client-planning-entry-1')));
      await t.pumpAndSettle();
      expect(find.text('Cambios pendientes de enviar'), findsNothing);
      expect(find.text('Garmin'), findsNothing);
    },
  );

  testWidgets(
    'reúne pautas por ID sin duplicar y la ajena solo permite lectura',
    (t) async {
      await mount(t);
      expect(
        find.byKey(const ValueKey('client-planning-entry-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('client-planning-entry-1')));
      await t.pumpAndSettle();
      expect(
        find.text('Solo lectura. Puedes consultar la pauta para coordinarte.'),
        findsOneWidget,
      );
      expect(find.text('Adaptar solo esta pauta'), findsNothing);
      expect(find.text('Mover fecha'), findsNothing);
      await t.tap(find.byKey(const ValueKey('client-planning-entry-0')));
      await t.pumpAndSettle();
      expect(find.text('Adaptar solo esta pauta'), findsOneWidget);
      expect(find.text('Mover fecha'), findsOneWidget);
    },
  );
  testWidgets(
    'revocar o fallar la consulta compartida retira las pautas ajenas',
    (t) async {
      final shared = CalendarFixture();
      await mount(t, shared: shared);
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsOneWidget,
      );
      shared.shared = false;
      await t.tap(find.byTooltip('Actualizar planificación'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('client-planning-entry-0')),
        findsOneWidget,
      );
      shared.shared = true;
      await t.tap(find.byTooltip('Actualizar planificación'));
      await t.pumpAndSettle();
      shared.denied = true;
      await t.tap(find.byTooltip('Actualizar planificación'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('client-planning-entry-1')),
        findsNothing,
      );
      expect(
        find.textContaining('Solo se muestran tus pautas'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'biblioteca pauta al alumno abierto y fecha seleccionada sin buscar destinatario',
    (t) async {
      final workouts = WorkoutFixture();
      await mount(t, workouts: workouts);
      await t.tap(find.byTooltip('Pautar el 28/10/2026'));
      await t.pumpAndSettle();
      await t.tap(find.text(privateRecipe.name).last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Asignar sesión').last,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('Asignar sesión').last);
      await t.pumpAndSettle();
      expect(workouts.assigned.single.relation, 'relation');
      expect(workouts.assigned.single.date, DateTime(2026, 10, 28));
    },
  );
  testWidgets(
    'crear sesión conserva el día y entrega la receta guardada a la confirmación',
    (t) async {
      final workouts = WorkoutFixture();
      var created = 0;
      await mount(
        t,
        workouts: workouts,
        createSession: (_) async {
          created++;
          return 'template';
        },
      );
      await t.tap(find.byTooltip('Pautar el 28/10/2026'));
      await t.pumpAndSettle();
      await t.tap(find.text('Volver'));
      await t.pumpAndSettle();
      await t.tap(find.text('Crear sesión').first);
      await t.pumpAndSettle();
      expect(created, 1);
      expect(workouts.assigned, isEmpty);
      await t.ensureVisible(find.text('Asignar sesión').last);
      await t.tap(find.text('Asignar sesión').last);
      await t.pumpAndSettle();
      expect(workouts.assigned.single.date, DateTime(2026, 10, 28));
      expect(workouts.assigned.single.relation, 'relation');
    },
  );
  testWidgets(
    'arrastrar desde la biblioteca prepara una confirmación para ese día',
    (t) async {
      final workouts = WorkoutFixture();
      await mount(t, workouts: workouts, width: 1920);
      final source = find
          .byType(Draggable<ProfessionalLibraryDrag<TrainerWorkout>>)
          .first;
      final target = find.byKey(
        const ValueKey('client-calendar-drop-2026-10-28'),
      );
      await t.drag(source, t.getCenter(target) - t.getCenter(source));
      await t.pumpAndSettle();
      expect(find.byType(TrainerAssignmentDialog), findsOneWidget);
      expect(workouts.assigned, isEmpty);
      await t.ensureVisible(find.text('Asignar sesión').last);
      await t.tap(find.text('Asignar sesión').last);
      await t.pumpAndSettle();
      expect(workouts.assigned.single.date, DateTime(2026, 10, 28));
    },
  );
  testWidgets('una respuesta tardía no trae pautas del alumno anterior', (
    t,
  ) async {
    final planning = PlanningFixture();
    await mount(t, planning: planning, client: 'first');
    final pending = Completer<TrainerClientAgendaPage>();
    planning.pending = pending;
    await t.tap(find.byTooltip('Actualizar planificación'));
    await t.pump();
    planning.pending = null;
    await mount(t, planning: planning, client: 'second');
    pending.complete(
      TrainerClientAgendaPage(
        items: [
          TrainerClientAgendaItem.fromJson({
            'id': 'private-old',
            'template_id': 'template',
            'template_name': 'Privado del alumno anterior',
            'template_version': 1,
            'scheduled_date': '2026-10-26',
            'status': 'planned',
            'created_at': '2026-10-25T10:00:00Z',
          }),
        ],
        hasMore: false,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Privado del alumno anterior'), findsNothing);
    expect(planning.calls.last.id, 'second');
  });
  testWidgets(
    'la semana civil no pierde el lunes al cambiar de mes u horario',
    (t) async {
      final planning = PlanningFixture();
      await mount(t, planning: planning);
      await t.tap(find.byTooltip('Semana anterior'));
      await t.pumpAndSettle();
      expect(planning.calls.last.from, DateTime(2026, 10, 19));
      expect(planning.calls.last.to, DateTime(2026, 10, 25));
      await t.tap(find.byTooltip('Semana siguiente'));
      await t.pumpAndSettle();
      expect(planning.calls.last.from, DateTime(2026, 10, 26));
    },
  );
  testWidgets(
    'crear un programa prepara sus fechas para el alumno sin asignarlo aún',
    (t) async {
      final programs = ProgramFixture();
      await mount(t, programs: programs, createProgram: (_) async => 'program');
      await t.tap(find.text('Crear programa').first);
      await t.pumpAndSettle();
      expect(find.text('Resumen de la pauta'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Confirmar 2 sesiones'),
        250,
        maxScrolls: 20,
        scrollable: find
            .descendant(
              of: find.byType(TrainerProgramAssignmentDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Confirmar 2 sesiones'), findsOneWidget);
      expect(programs.assigned, isEmpty);
    },
  );
  testWidgets(
    'guardar programa devuelve su identidad al contexto que lo abrió',
    (t) async {
      String? saved;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerProgramEditorPage(
            repository: ProgramFixture(),
            workouts: WorkoutFixture(),
            programId: 'program',
            onSaved: (id) => saved = id,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Guardar programa privado'),
        300,
        maxScrolls: 40,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Guardar programa privado'));
      await t.pumpAndSettle();
      expect(saved, 'program-saved');
    },
  );
  for (final width in [320.0, 1000.0, 1600.0]) {
    testWidgets('calendario y acciones legibles a $width con texto ampliado', (
      t,
    ) async {
      await mount(t, width: width, scale: 2);
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('client-calendar-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('client-planning-entry-1')),
        200,
        scrollable: scroll,
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
