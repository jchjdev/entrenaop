import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_month_calendar.dart';
import 'package:entrenaop_trainer/trainer_appointment_week.dart';
import 'package:entrenaop_trainer/trainer_pointer_drag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_appointments.dart';

import '../../packages/trainer_access/test/appointment_fixtures.dart';
import 'trainer_agenda_edit_test.dart' as agenda;

void main() {
  testWidgets(
    'arrastra una cita a otro día sin el diálogo de asignación de sesiones',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AppointmentFixture();
      await tester.pumpWidget(
        agenda.app(
          TrainerAgendaPage(
            repository: agenda.AgendaEditFixture(),
            appointments: repo,
            now: DateTime(2026, 10, 28),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is TrainerCalendarEntryTile && widget.entry.appointment,
      );
      final target = find.byKey(
        const ValueKey('appointment-day-drop-2026-10-29'),
      );
      await tester.ensureVisible(tile.first);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(tile.first),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(15, 4));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repo.moved?.day, DateTime(2026, 10, 29));
      expect(repo.moved?.minute, 660);
      expect(find.text('Asignar sesión privada'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'el tablero horario acepta soltar sobre otra cita y conserva las sesiones sin hora',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AppointmentFixture();
      repo.rows.add(
        TrainerAppointment.fromJson(
          appointmentJson(id: 'second', day: 29, minute: 720),
        ),
      );
      int? minute;
      DateTime? day;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerAppointmentWeek(
              firstDay: DateTime(2026, 10, 26),
              entries: const [],
              appointments: repo.rows,
              enabled: true,
              onOpen: (_) {},
              onMove: (_, d, m) {
                day = d;
                minute = m;
              },
              dragBuilder: (row, child) => TrainerPointerDrag(
                data: row,
                feedback: const Material(child: Text('Moviendo cita')),
                child: child,
              ),
              dayDropBuilder: (_, child) => child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final source = find.byKey(
        const ValueKey('appointment-hour-appointment-2026-10-28'),
      );
      final target = find.byKey(
        const ValueKey('appointment-hour-second-2026-10-29'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(source),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(day, DateTime(2026, 10, 29));
      expect(minute, 720);
      expect(find.text('Sin hora · soltar sesión'), findsNWidgets(7));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('un fallo de citas no oculta los entrenamientos existentes', (
    tester,
  ) async {
    final repo = AppointmentFixture()..fail = true;
    await tester.pumpWidget(
      agenda.app(
        TrainerAgendaPage(
          repository: agenda.AgendaEditFixture(),
          appointments: repo,
          now: DateTime(2026, 10, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Tus entrenamientos se conservan.'),
      300,
      maxScrolls: 30,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Tus entrenamientos se conservan.'),
      findsOneWidget,
    );
    expect(find.text('Sesión one'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
