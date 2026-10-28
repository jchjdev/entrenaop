import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_rpc.dart';

String appointmentDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class TrainerAppointment {
  TrainerAppointment.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      relationId = row['relation_id'] as String,
      trainerId = row['trainer_id'] as String,
      clientId = row['client_id'] as String,
      trainerName = row['trainer_name'] as String,
      clientName = row['client_name'] as String,
      title = row['title'] as String,
      startsAt = DateTime.parse(row['starts_at'] as String),
      // Hora civil en la zona de la cita; no reinterpretarla en la del teléfono.
      localStart = DateTime.parse(row['local_start'] as String),
      calendarStart = DateTime.parse(
        (row['calendar_start'] ?? row['local_start']) as String,
      ),
      calendarEnd = row['calendar_end'] == null
          ? DateTime.parse(
              row['local_start'] as String,
            ).add(Duration(minutes: (row['duration_minutes'] as num).toInt()))
          : DateTime.parse(row['calendar_end'] as String),
      calendarTimezone =
          (row['calendar_timezone'] ?? row['timezone']) as String,
      durationMinutes = (row['duration_minutes'] as num).toInt(),
      timezone = row['timezone'] as String,
      location = row['location'] as String,
      status = row['status'] as String,
      revision = (row['revision'] as num).toInt(),
      suggestedReminder = (row['suggested_reminder'] as num).toInt(),
      studentReminder = (row['student_reminder'] as num).toInt(),
      reminderRevision = (row['reminder_revision'] as num).toInt(),
      editable = row['editable'] == true,
      canRemind = row['can_remind'] == true;
  final String id, relationId, trainerId, clientId, trainerName, clientName;
  final String title, timezone, location, status;
  final DateTime startsAt, localStart;
  final DateTime calendarStart, calendarEnd;
  final String calendarTimezone;
  final int durationMinutes,
      revision,
      suggestedReminder,
      studentReminder,
      reminderRevision;
  final bool editable, canRemind;
  bool get cancelled => status == 'cancelled';
  int get minute => localStart.hour * 60 + localStart.minute;
  String get timeLabel =>
      '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
  String get dateLabel =>
      '${localStart.day}/${localStart.month}/${localStart.year}';
}

class AppointmentDraft {
  const AppointmentDraft({
    required this.id,
    required this.relationId,
    required this.title,
    required this.day,
    required this.minute,
    required this.durationMinutes,
    required this.timezone,
    this.revision = 0,
    this.location = '',
    this.suggestedReminder = 0,
  });
  factory AppointmentDraft.fromAppointment(
    TrainerAppointment value, {
    DateTime? day,
    int? minute,
  }) => AppointmentDraft(
    id: value.id,
    relationId: value.relationId,
    title: value.title,
    day: day ?? value.localStart,
    minute: minute ?? value.minute,
    durationMinutes: value.durationMinutes,
    timezone: value.timezone,
    revision: value.revision,
    location: value.location,
    suggestedReminder: value.suggestedReminder,
  );
  final String id, relationId, title, timezone, location;
  final DateTime day;
  final int minute, durationMinutes, revision, suggestedReminder;
  String? get validationError {
    if (title.trim().isEmpty || title.trim().length > 120) {
      return 'Escribe un motivo de hasta 120 caracteres.';
    }
    if (minute < 0 ||
        minute > 1439 ||
        durationMinutes < 15 ||
        durationMinutes > 720) {
      return 'Revisa la hora y la duración (15 a 720 minutos).';
    }
    if (location.trim().length > 500 ||
        timezone.isEmpty ||
        !const [0, 30, 1440].contains(suggestedReminder)) {
      return 'Revisa el lugar y el recordatorio.';
    }
    return null;
  }
}

class AppointmentPage {
  const AppointmentPage(this.items, {this.hasMore = false});
  final List<TrainerAppointment> items;
  final bool hasMore;
}

class AppointmentSaveResult {
  const AppointmentSaveResult({
    this.appointment,
    this.requiresConfirmation = false,
  });
  final TrainerAppointment? appointment;
  final bool requiresConfirmation;
}

abstract interface class TrainerAppointmentRepository {
  Future<AppointmentPage> list({
    DateTime? from,
    DateTime? to,
    TrainerAppointment? after,
    bool history = false,
  });
  Future<TrainerAppointment> get(String id);
  Future<AppointmentSaveResult> save(
    AppointmentDraft value, {
    bool allowOverlap = false,
  });
  Future<AppointmentSaveResult> move(
    TrainerAppointment value,
    DateTime day,
    int minute, {
    bool allowOverlap = false,
  });
  Future<TrainerAppointment> cancel(TrainerAppointment value);
  Future<TrainerAppointment> reminder(TrainerAppointment value, int minutes);
}

class SupabaseTrainerAppointmentRepository
    implements TrainerAppointmentRepository {
  const SupabaseTrainerAppointmentRepository(
    this.client,
    this.owner, {
    required this.forTrainer,
  });
  final SupabaseClient client;
  final String owner;
  final bool forTrainer;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(
        client,
        owner,
        name,
        params: {'p_expected_owner': owner, ...params},
      );
  Map<String, dynamic> _row(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  @override
  Future<AppointmentPage> list({
    DateTime? from,
    DateTime? to,
    TrainerAppointment? after,
    bool history = false,
  }) async {
    final result = _row(
      await _rpc(
        forTrainer ? 'list_trainer_appointments' : 'list_my_appointments',
        {
          if (forTrainer) ...{
            'p_from': appointmentDay(from!),
            'p_to': appointmentDay(to!),
          } else
            'p_history': history,
          'p_after_at': after?.startsAt.toUtc().toIso8601String(),
          'p_after_id': after?.id,
        },
      ),
    );
    return AppointmentPage(
      (result['items'] as List)
          .map((r) => TrainerAppointment.fromJson(_row(r)))
          .toList(),
      hasMore: result['has_more'] == true,
    );
  }

  @override
  Future<TrainerAppointment> get(String id) async =>
      TrainerAppointment.fromJson(
        _row(
          await _rpc(
            forTrainer ? 'get_trainer_appointment' : 'get_my_appointment',
            {'p_id': id},
          ),
        ),
      );
  @override
  Future<AppointmentSaveResult> save(
    AppointmentDraft value, {
    bool allowOverlap = false,
  }) async {
    if (!forTrainer) {
      throw StateError('Solo el preparador puede crear o mover citas.');
    }
    final error = value.validationError;
    if (error != null) throw FormatException(error);
    final row = _row(
      await _rpc('save_trainer_appointment', {
        'p_id': value.id,
        'p_revision': value.revision,
        'p_relation': value.relationId,
        'p_title': value.title.trim(),
        'p_day': appointmentDay(value.day),
        'p_minute': value.minute,
        'p_duration': value.durationMinutes,
        'p_timezone': value.timezone,
        'p_location': value.location.trim(),
        'p_suggestion': value.suggestedReminder,
        'p_overlap': allowOverlap,
      }),
    );
    return AppointmentSaveResult(
      requiresConfirmation: row['requires_confirmation'] == true,
      appointment: row['appointment'] == null
          ? null
          : TrainerAppointment.fromJson(_row(row['appointment'])),
    );
  }

  @override
  Future<AppointmentSaveResult> move(
    TrainerAppointment value,
    DateTime day,
    int minute, {
    bool allowOverlap = false,
  }) async {
    if (!forTrainer) throw StateError('Solo el preparador puede mover citas.');
    final row = _row(
      await _rpc('move_trainer_appointment', {
        'p_id': value.id,
        'p_revision': value.revision,
        'p_day': appointmentDay(day),
        'p_minute': minute,
        'p_overlap': allowOverlap,
      }),
    );
    return AppointmentSaveResult(
      requiresConfirmation: row['requires_confirmation'] == true,
      appointment: row['appointment'] == null
          ? null
          : TrainerAppointment.fromJson(_row(row['appointment'])),
    );
  }

  @override
  Future<TrainerAppointment> cancel(TrainerAppointment value) async {
    if (!forTrainer) {
      throw StateError('Solo el preparador puede cancelar la cita.');
    }
    return TrainerAppointment.fromJson(
      _row(
        await _rpc('cancel_trainer_appointment', {
          'p_id': value.id,
          'p_revision': value.revision,
        }),
      ),
    );
  }

  @override
  Future<TrainerAppointment> reminder(
    TrainerAppointment value,
    int minutes,
  ) async => TrainerAppointment.fromJson(
    _row(
      await _rpc('set_my_appointment_reminder', {
        'p_id': value.id,
        'p_revision': value.revision,
        'p_reminder_revision': value.reminderRevision,
        'p_minutes': minutes,
      }),
    ),
  );
}
