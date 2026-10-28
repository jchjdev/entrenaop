import 'dart:async';

import 'package:entrenaop/features/trainers/presentation/pages/student_appointments_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_appointments.dart';

import '../../../packages/trainer_access/test/appointment_fixtures.dart';

void main() {
  test('la hora civil no se convierte usando la zona del teléfono', () {
    final row = TrainerAppointment.fromJson(appointmentJson());
    expect(row.startsAt.hour, 10);
    expect(row.startsAt.isUtc, true);
    expect(row.localStart.hour, 11);
    expect(row.localStart.isUtc, false);
    expect(row.timeLabel, '11:00');
    expect(row.calendarEnd.difference(row.calendarStart).inMinutes, 45);
    final draft = AppointmentDraft.fromAppointment(
      row,
      day: DateTime(2026, 11, 2),
    );
    expect(draft.minute, 660);
    expect(draft.durationMinutes, 45);
    expect(draft.timezone, 'Europe/Madrid');
    expect(draft.revision, 1);
    expect(draft.validationError, isNull);
  });
  testWidgets('recordatorio apagado hasta la elección explícita del alumno', (
    tester,
  ) async {
    final repo = AppointmentFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAppointmentsPage(repository: repo, userId: 'pupil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.reminders, 0);
    expect(find.text('Revisión técnica'), findsOneWidget);
    expect(find.text('Sin recordatorio'), findsWidgets);
    final dropdown = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutos antes').last);
    await tester.pumpAndSettle();
    expect(repo.reminders, 1);
    expect(repo.rows.single.studentReminder, 30);
  });
  testWidgets(
    'cancelada conserva consulta sin activar recordatorios y actualiza al recibir avisos',
    (tester) async {
      final repo = AppointmentFixture()
        ..rows = [
          TrainerAppointment.fromJson(appointmentJson(cancelled: true)),
        ];
      final notices = StreamController<void>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: StudentAppointmentsPage(
            repository: repo,
            userId: 'pupil',
            appointmentId: 'appointment',
            notices: notices.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Cita cancelada. Se conserva en tu historial.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      repo.rows = [TrainerAppointment.fromJson(appointmentJson(minute: 720))];
      notices.add(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('12:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await notices.close();
    },
  );
  testWidgets('lista utilizable con texto ampliado en móvil', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: StudentAppointmentsPage(
          repository: AppointmentFixture(),
          userId: 'pupil',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
