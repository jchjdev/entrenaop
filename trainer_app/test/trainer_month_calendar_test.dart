import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_month_calendar.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/performance_visual_review.dart';
import 'professional_desktop_test.dart' show dragTo, resize;
import 'trainer_agenda_edit_test.dart' show AgendaEditFixture, item;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

void main() {
  testWidgets(
    'permite retirar desde la tira y recarga; ejecución iniciada queda protegida',
    (t) async {
      await resize(t, const Size(1500, 1200));
      final agenda = AgendaEditFixture();
      final workouts = _WithdrawalFixture(agenda);
      await t.pumpWidget(
        MaterialApp(
          home: TrainerAgendaPage(
            repository: agenda,
            workouts: workouts,
            now: DateTime(2026, 10, 21),
          ),
        ),
      );
      await t.pumpAndSettle();
      final strip = find.byKey(
        const ValueKey('agenda-month-event-session-one'),
      );
      await t.ensureVisible(strip);
      await t.tap(strip);
      await t.pumpAndSettle();
      await t.tap(find.text('Retirar sesión').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Retirar sesión').last);
      await t.pumpAndSettle();
      expect(workouts.cancelled, ['one']);
      expect(agenda.calls.length, 2);
    },
  );

  setUpAll(loadReviewFont);

  testWidgets('altura compacta conserva entradas, detalle y escala de texto', (
    t,
  ) async {
    await resize(t, const Size(1366, 768));
    Widget page(bool compact, {double scale = 1}) => MaterialApp(
      theme: EntrenaTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: TrainerMonthCalendar(
              compact: compact,
              anchor: DateTime(2026, 10, 21),
              today: DateTime(2026, 10, 21),
              entries: [
                for (var i = 0; i < 3; i++)
                  TrainerCalendarEntry(
                    id: '$i',
                    date: DateTime(2026, 10, 21),
                    personId: 'client',
                    personName: 'Ana Soria',
                    title: 'Sesión $i',
                    stateLabel: 'Pendiente',
                    onTap: () {},
                  ),
              ],
              onSelectDate: (_) {},
              dropTargetBuilder: (_, child) => child,
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(page(false));
    await t.pumpAndSettle();
    final fullHeight = t.getSize(find.byType(TrainerMonthCalendar)).height;
    await t.pumpWidget(page(true));
    await t.pumpAndSettle();
    expect(
      t.getSize(find.byType(TrainerMonthCalendar)).height,
      lessThan(fullHeight * .75),
    );
    expect(find.text('Sesión 0'), findsOneWidget);
    expect(find.text('Sesión 1'), findsNothing);
    final more = find.byKey(const ValueKey('agenda-month-more-2026-10-21'));
    await t.ensureVisible(more);
    await t.tap(more);
    await t.pumpAndSettle();
    expect(find.text('Sesión 2\nPendiente'), findsOneWidget);
    await t.tap(find.text('Cerrar'));
    await t.pumpAndSettle();
    await t.pumpWidget(page(true, scale: 2));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('cambiar densidad conserva fecha y datos sin recargar', (
    t,
  ) async {
    await resize(t, const Size(1366, 768));
    final repository = AgendaEditFixture();
    await t.pumpWidget(
      MaterialApp(
        home: ProfessionalWorkspaceScope(
          desktop: true,
          child: TrainerAgendaPage(
            repository: repository,
            now: DateTime(2026, 10, 21),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<TrainerMonthCalendar>(find.byType(TrainerMonthCalendar)).compact,
      isTrue,
    );
    final calls = repository.calls.length;
    await t.ensureVisible(find.byKey(const ValueKey('agenda-day-21')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('agenda-day-21')));
    await t.pumpAndSettle();
    final selected = t
        .widget<TrainerMonthCalendar>(find.byType(TrainerMonthCalendar))
        .selected;
    expect(selected, DateTime(2026, 10, 21));
    final density = find.byKey(const ValueKey('agenda-calendar-density'));
    await t.scrollUntilVisible(
      density,
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('trainer-agenda-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(density);
    await t.pumpAndSettle();
    await t.tap(find.text('Mes amplio').last);
    await t.pumpAndSettle();
    final calendar = t.widget<TrainerMonthCalendar>(
      find.byType(TrainerMonthCalendar),
    );
    expect(calendar.compact, isFalse);
    expect(calendar.selected, selected);
    expect(repository.calls.length, calls);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'ratón mueve la tira sin pulsación larga en una ventana compacta',
    (t) async {
      await resize(t, const Size(900, 1200));
      final moved = <DateTime>[];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProfessionalWorkspaceScope(
            desktop: false,
            child: TrainerAgendaPage(
              repository: AgendaEditFixture(),
              now: DateTime(2026, 10, 21),
              onMove: (_, date) async => moved.add(date),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final source = find.byKey(const ValueKey('agenda-month-drag-one'));
      final target = find.byKey(const ValueKey('agenda-drop-2026-10-22'));
      await t.ensureVisible(source);
      await t.pumpAndSettle();
      final gesture = await t.startGesture(
        t.getCenter(source),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(24, 0));
      await t.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(t.getCenter(target));
      await t.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await t.pumpAndSettle();
      expect(moved, [DateTime(2026, 10, 22)]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'el mes muestra alumno y sesión; el excedente abre las entradas del día',
    (t) async {
      await resize(t, const Size(1500, 1200));
      final selected = <DateTime>[];
      final opened = <int>[];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrainerMonthCalendar(
                anchor: DateTime(2026, 10, 27),
                today: DateTime(2026, 10, 27),
                entries: [
                  for (var i = 0; i < 3; i++)
                    TrainerCalendarEntry(
                      id: '$i',
                      date: DateTime(2026, 10, 27),
                      personId: 'pupil-$i',
                      personName: ['Ana Soria', 'Luis Vega', 'Celia Martín'][i],
                      title: ['Fuerza A', 'Series 200 m', 'Rodaje suave'][i],
                      stateLabel: 'Pendiente',
                      onTap: () => opened.add(i),
                    ),
                ],
                onSelectDate: selected.add,
                dropTargetBuilder: (_, child) => child,
                partial: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-month-event-0')),
        findsOneWidget,
      );
      expect(find.text('Fuerza A'), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda-month-event-2')), findsNothing);
      final more = find.byKey(const ValueKey('agenda-month-more-2026-10-27'));
      await t.ensureVisible(more);
      await t.tap(more);
      await t.pumpAndSettle();
      expect(selected, [DateTime(2026, 10, 27)]);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Celia Martín')),
        findsOneWidget,
      );
      expect(
        find.text('Se muestran las entradas cargadas de este día.'),
        findsOneWidget,
      );
      await t.tap(
        find.descendant(of: dialog, matching: find.text('Celia Martín')),
      );
      await t.pumpAndSettle();
      expect(opened, [2]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'los días adyacentes navegan y no se ofrecen como destinos sin consultar',
    (t) async {
      final destinations = <DateTime>{};
      final adjacent = <DateTime>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrainerMonthCalendar(
                anchor: DateTime(2026, 10, 1),
                today: DateTime(2026, 10, 27),
                entries: const [],
                onSelectDate: (_) {},
                onSelectAdjacentDate: adjacent.add,
                dropTargetBuilder: (date, child) {
                  destinations.add(date);
                  return child;
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(destinations, hasLength(31));
      expect(destinations.every((d) => d.month == 10), isTrue);
      final previous = find.descendant(
        of: find.byKey(const ValueKey('agenda-cell-2026-9-28')),
        matching: find.byType(TextButton),
      );
      await t.ensureVisible(previous);
      await t.tap(previous);
      await t.pumpAndSettle();
      expect(adjacent, [DateTime(2026, 9, 28)]);
    },
  );

  testWidgets(
    'arrastrar una tira del mes reutiliza el movimiento y conserva la cita',
    (t) async {
      await resize(t, const Size(1700, 1500));
      final repo = AgendaEditFixture();
      final moved = <({String id, DateTime date})>[];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProfessionalWorkspaceScope(
            desktop: true,
            child: TrainerAgendaPage(
              repository: repo,
              now: DateTime(2026, 10, 21),
              onMove: (assignment, date) async {
                moved.add((id: assignment.id, date: date));
                repo.rows = [item('one', day: date.day)];
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final source = find.byKey(const ValueKey('agenda-month-drag-one'));
      final target = find.byKey(const ValueKey('agenda-drop-2026-10-22'));
      await t.ensureVisible(source);
      await t.pumpAndSettle();
      expect(moved, isEmpty);
      await dragTo(t, source, t.getCenter(target));
      expect(moved, [(id: 'one', date: DateTime(2026, 10, 22))]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('agenda-cell-2026-10-22')),
          matching: find.byKey(
            const ValueKey('agenda-month-event-session-one'),
          ),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'una sesión iniciada se consulta sin ofrecer arrastre, cambio o adaptación',
    (t) async {
      await resize(t, const Size(1400, 1400));
      final repo = AgendaEditFixture()
        ..rows = [item('started', execution: 'execution')];
      var writes = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProfessionalWorkspaceScope(
            desktop: true,
            child: TrainerAgendaPage(
              repository: repo,
              workouts: WorkoutFixture(),
              now: DateTime(2026, 10, 21),
              onMove: (_, _) async {
                writes++;
              },
              onAdapt: (_) async {
                writes++;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agenda-month-drag-started')),
        findsNothing,
      );
      final event = find.byKey(
        const ValueKey('agenda-month-event-session-started'),
      );
      await t.ensureVisible(event);
      await t.tap(event);
      await t.pumpAndSettle();
      final dialog = find.byKey(const ValueKey('agenda-session-panel'));
      expect(
        find.descendant(of: dialog, matching: find.text('Ana de prueba')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Mover fecha')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Adaptar pauta')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Ver resultados')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Retirar sesión')),
        findsNothing,
      );
      expect(writes, 0);
    },
  );

  testWidgets(
    'captura del tablero mensual con biblioteca y eventos reales del widget',
    (t) async {
      await resize(t, const Size(1760, 1400));
      final repo = AgendaEditFixture()
        ..rows = [
          item('Fuerza A', day: 19),
          item('Rodaje suave', pupil: 'luis', day: 20),
          item('Dominadas y core', day: 21),
          item('Series 200 m', pupil: 'luis', day: 21),
          item('Movilidad', day: 21),
          item('Fuerza B', day: 23),
          item('Carrera continua', pupil: 'luis', day: 26),
          item('Fuerza y técnica', day: 27),
          item('Rodaje retirado', pupil: 'luis', day: 28, status: 'cancelled'),
          item('Recuperación', day: 30, status: 'completed', execution: 'done'),
        ];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: ProfessionalWorkspaceScope(
              desktop: true,
              child: TrainerShell(
                location: '/agenda',
                child: TrainerAgendaPage(
                  repository: repo,
                  now: DateTime(2026, 10, 27),
                  workouts: WorkoutFixture(),
                  onMove: (_, _) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capturePerformanceWidget(t, 'trainer-month-calendar');
      t.view.physicalSize = const Size(1366, 768);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TrainerMonthCalendar>(find.byType(TrainerMonthCalendar))
            .compact,
        isTrue,
      );
      expect(t.takeException(), isNull);
      await capturePerformanceWidget(t, 'trainer-month-1366-compact');
    },
  );
}

class _WithdrawalFixture extends WorkoutFixture {
  _WithdrawalFixture(this.agenda);
  final AgendaEditFixture agenda;
  final cancelled = <String>[];
  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    agenda.rows = [];
  }
}
