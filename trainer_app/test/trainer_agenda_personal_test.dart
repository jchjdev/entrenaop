import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_month_calendar.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';

import 'trainer_agenda_edit_test.dart' as agenda;

TrainerAgendaItem ownItem(String id, String client) =>
    TrainerAgendaItem.fromJson({
      'id': id,
      'template_id': 'template',
      'template_name': 'Pauta propia $id',
      'template_version': 1,
      'scheduled_date': '2026-11-03',
      'created_at': '2026-10-30T10:00:00Z',
      'status': 'planned',
      'client_id': client,
      'client_name': client == 'javier' ? 'Javier Charlez' : 'Ana',
    });

class PersonalCalendar implements TrainerSharedCalendarRepository {
  final calls =
      <({String client, DateTime from, DateTime to, String? after})>[];
  final recipeReads = <String>[];
  bool denied = false, paginated = false;
  @override
  Future<SharedCalendarPage> calendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async {
    calls.add((client: clientId, from: from, to: to, after: after?.id));
    if (denied) throw StateError('Sin conexión');
    return SharedCalendarPage.fromJson({
      'shared': true,
      'has_more': paginated && after == null,
      'coaches': <Object>[],
      'items': [
        if (after == null)
          {
            'id': 'self',
            'scheduled_date': from.toIso8601String(),
            'template_name': 'Autoasignada',
            'source': 'coach',
            'status': 'planned',
            'is_own': true,
          },
        if (!paginated || after != null)
          for (final status in ['planned', 'cancelled'])
            {
              'id': status,
              'scheduled_date': from.toIso8601String(),
              'template_name': 'Series de Ervigio $status',
              'source': 'coach',
              'status': status,
              'is_own': false,
              'trainer_name': 'Ervigio Jorge',
              'is_running': true,
            },
      ],
    });
  }

  @override
  Future<Map<String, dynamic>> workout(
    String clientId,
    String scheduledId,
  ) async {
    recipeReads.add('$clientId/$scheduledId');
    return {
      'id': 'recipe',
      'name': 'Series de Ervigio',
      'version': 1,
      'workout_blocks': <Object>[],
    };
  }
}

Future<void> mount(
  WidgetTester t,
  PersonalCalendar personal, {
  agenda.AgendaEditFixture? own,
  bool desktop = false,
}) async {
  t.view.physicalSize = const Size(1200, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: ProfessionalWorkspaceScope(
        desktop: desktop,
        child: TrainerAgendaPage(
          repository: own ?? (agenda.AgendaEditFixture()..rows = []),
          personalCalendar: personal,
          personalClientId: 'javier',
          now: DateTime(2026, 11, 3),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('pautas recibidas también en semana de escritorio, día y lista', (
    t,
  ) async {
    await mount(t, PersonalCalendar(), desktop: true);
    for (final view in ['week', 'day', 'list']) {
      await agenda.tapVisible(t, find.byKey(ValueKey('agenda-view-$view')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-received-planned')),
        findsOneWidget,
      );
      if (view == 'week') {
        final tiles = t.widgetList<TrainerCalendarEntryTile>(
          find.byType(TrainerCalendarEntryTile),
        );
        expect(
          tiles.where((tile) => tile.entry.id == 'received-planned'),
          hasLength(1),
        );
      }
      expect(t.takeException(), isNull);
    }
  });
  testWidgets(
    'agenda incluye lo recibido, con autor y sin duplicar autoasignación',
    (t) async {
      final p = PersonalCalendar();
      await mount(t, p);
      expect(p.calls.single.client, 'javier');
      expect(p.calls.single.from, DateTime(2026, 11));
      expect(p.calls.single.to, DateTime(2026, 11, 30));
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-planned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-self')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-cancelled')),
        findsNothing,
      );
      expect(find.text('Para mí · Ervigio Jorge'), findsWidgets);
      final tile = t.widget<TrainerCalendarEntryTile>(
        find.byKey(const ValueKey('agenda-month-event-received-planned')),
      );
      expect(tile.entry.dragBuilder, isNull);
      expect(find.text('No hay pautas en esta selección.'), findsNothing);
    },
  );

  testWidgets('receta recibida se abre sin operaciones de autoría', (t) async {
    final p = PersonalCalendar();
    await mount(t, p);
    await agenda.tapVisible(
      t,
      find.byKey(const ValueKey('agenda-received-planned')),
    );
    await t.pumpAndSettle();
    expect(p.recipeReads, ['javier/planned']);
    expect(find.text('Ervigio Jorge · Solo lectura'), findsOneWidget);
    expect(find.text('Retirar pauta'), findsNothing);
    expect(find.text('Adaptar pauta'), findsNothing);
    expect(find.text('Mover fecha'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('retiradas y cambio de periodo incluyen la agenda personal', (
    t,
  ) async {
    final p = PersonalCalendar();
    await mount(t, p);
    await agenda.tapVisible(t, find.text('Retiradas'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-cancelled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-planned')),
      findsNothing,
    );
    await agenda.tapVisible(t, find.byTooltip('Mes siguiente'));
    await t.pumpAndSettle();
    expect(p.calls.last.from, DateTime(2026, 12));
    expect(p.calls.last.to, DateTime(2026, 12, 31));
    await agenda.tapVisible(t, find.text('Archivadas'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-cancelled')),
      findsNothing,
    );
  });

  testWidgets('paginación usa el último elemento bruto aunque sea propio', (
    t,
  ) async {
    final p = PersonalCalendar()..paginated = true;
    await mount(t, p);
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-planned')),
      findsNothing,
    );
    await agenda.tapVisible(t, find.text('Cargar más sesiones recibidas'));
    await t.pumpAndSettle();
    expect(p.calls.last.after, 'self');
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-planned')),
      findsOneWidget,
    );
    expect(find.text('Cargar más sesiones recibidas'), findsNothing);
  });

  testWidgets('fallo personal no oculta pautas propias y permite reintentar', (
    t,
  ) async {
    final p = PersonalCalendar()..denied = true;
    final own = agenda.AgendaEditFixture()..rows = [ownItem('one', 'javier')];
    await mount(t, p, own: own);
    expect(
      find.text('No se pudieron cargar las sesiones de tus preparadores.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agenda-month-event-session-one')),
      findsOneWidget,
    );
    p.denied = false;
    await agenda.tapVisible(t, find.text('Reintentar sesiones recibidas'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agenda-month-event-received-planned')),
      findsOneWidget,
    );
    expect(
      find.text('No se pudieron cargar las sesiones de tus preparadores.'),
      findsNothing,
    );
  });

  testWidgets(
    'filtrar otro alumno no mezcla las pautas personales del entrenador',
    (t) async {
      final own = agenda.AgendaEditFixture()
        ..rows = [ownItem('self', 'javier'), ownItem('ana', 'ana')];
      await mount(t, PersonalCalendar(), own: own);
      final field = find.byKey(const ValueKey('agenda-client-filter'));
      t.widget<DropdownButtonFormField<String>>(field).onChanged!('ana');
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-planned')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agenda-month-event-session-ana')),
        findsOneWidget,
      );
      t.widget<DropdownButtonFormField<String>>(field).onChanged!('javier');
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-planned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agenda-month-event-session-self')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-self')),
        findsNothing,
      );
      final state = find.byKey(const ValueKey('agenda-status-filter'));
      t.widget<DropdownButtonFormField<String>>(state).onChanged!('completed');
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-month-event-received-planned')),
        findsNothing,
      );
    },
  );
}
