import 'package:trainer_access/trainer_appointments.dart';

Map<String, dynamic> appointmentJson({
  String id = 'appointment',
  int day = 28,
  int minute = 660,
  int duration = 45,
  bool cancelled = false,
  bool editable = true,
  bool canRemind = true,
  int reminder = 0,
  int revision = 1,
}) => {
  'id': id,
  'relation_id': 'relation',
  'trainer_id': 'coach',
  'client_id': 'pupil',
  'trainer_name': 'Javier',
  'client_name': 'Isabel',
  'title': 'Revisión técnica',
  'starts_at': DateTime.utc(
    2026,
    10,
    day,
    minute ~/ 60 - 1,
    minute % 60,
  ).toIso8601String(),
  'local_start': DateTime(
    2026,
    10,
    day,
    minute ~/ 60,
    minute % 60,
  ).toIso8601String(),
  'calendar_start': DateTime(
    2026,
    10,
    day,
    minute ~/ 60,
    minute % 60,
  ).toIso8601String(),
  'calendar_end': DateTime(
    2026,
    10,
    day,
    minute ~/ 60,
    minute % 60,
  ).add(Duration(minutes: duration)).toIso8601String(),
  'calendar_timezone': 'Europe/Madrid',
  'duration_minutes': duration,
  'timezone': 'Europe/Madrid',
  'location': 'Pista municipal',
  'status': cancelled ? 'cancelled' : 'scheduled',
  'revision': revision,
  'suggested_reminder': 30,
  'student_reminder': reminder,
  'reminder_revision': 0,
  'editable': editable && !cancelled,
  'can_remind': canRemind && !cancelled,
};

class AppointmentFixture implements TrainerAppointmentRepository {
  List<TrainerAppointment> rows = [
    TrainerAppointment.fromJson(appointmentJson()),
  ];
  bool fail = false, conflict = false;
  int reminders = 0;
  int lists = 0;
  ({DateTime day, int minute})? moved;
  @override
  Future<AppointmentPage> list({
    DateTime? from,
    DateTime? to,
    TrainerAppointment? after,
    bool history = false,
  }) async {
    lists++;
    if (fail) throw StateError('Sin conexión');
    return AppointmentPage(rows);
  }

  @override
  Future<TrainerAppointment> get(String id) async =>
      rows.firstWhere((row) => row.id == id);
  @override
  Future<AppointmentSaveResult> save(
    AppointmentDraft value, {
    bool allowOverlap = false,
  }) async {
    if (conflict && !allowOverlap) {
      return const AppointmentSaveResult(requiresConfirmation: true);
    }
    rows = [
      TrainerAppointment.fromJson(
        appointmentJson(id: value.id, day: value.day.day, minute: value.minute),
      ),
    ];
    return AppointmentSaveResult(appointment: rows.single);
  }

  @override
  Future<AppointmentSaveResult> move(
    TrainerAppointment value,
    DateTime day,
    int minute, {
    bool allowOverlap = false,
  }) async {
    if (conflict && !allowOverlap) {
      return const AppointmentSaveResult(requiresConfirmation: true);
    }
    moved = (day: day, minute: minute);
    rows = [
      TrainerAppointment.fromJson(
        appointmentJson(
          day: day.day,
          minute: minute,
          revision: value.revision + 1,
        ),
      ),
    ];
    return AppointmentSaveResult(appointment: rows.single);
  }

  @override
  Future<TrainerAppointment> cancel(TrainerAppointment value) async {
    rows = [
      TrainerAppointment.fromJson(
        appointmentJson(cancelled: true, revision: value.revision + 1),
      ),
    ];
    return rows.single;
  }

  @override
  Future<TrainerAppointment> reminder(
    TrainerAppointment value,
    int minutes,
  ) async {
    reminders++;
    rows = [TrainerAppointment.fromJson(appointmentJson(reminder: minutes))];
    return rows.single;
  }
}
