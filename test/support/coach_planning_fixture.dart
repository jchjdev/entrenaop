import 'package:entrenaop/features/coach_workspace/domain/coach_planning_repository.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';
import 'package:workout_core/workout_template.dart';

TrainerClient planningPerson([String id = 'isabel']) => TrainerClient.fromJson({
  'person_id': id,
  'person_name': id == 'self' ? 'Para mí' : 'Isabel Rodríguez Fernández',
  'is_self': id == 'self',
  'created_at': '2026-10-20',
  'updated_at': '2026-10-20',
  'accepted_at': '2026-10-20',
  'active_relation_id': id == 'self' ? 'self-relation' : 'relation',
  'episode_count': 1,
});

class FakeCoachPlanning implements CoachPlanningRepository {
  int reads = 0;
  bool failAssignment = false;
  final assigned = <Map<String, Object>>[],
      moved = <Map<String, Object>>[],
      noteWrites = <Map<String, Object>>[],
      sentForms = <Map<String, Object>>[];
  final withdrawn = <String>[];
  @override
  final FakeCoachAppointments appointments = FakeCoachAppointments();
  @override
  Future<List<CoachLibrarySession>> sessions({
    CoachLibrarySession? before,
  }) async {
    reads++;
    return before == null
        ? [
            CoachLibrarySession(
              id: 'template',
              name: 'Fuerza de piernas',
              version: 2,
              isRunning: false,
              createdAt: DateTime(2026, 10, 20),
            ),
          ]
        : [];
  }

  @override
  Future<WorkoutTemplate> template(String id) async => WorkoutTemplate(
    id: id,
    name: 'Fuerza de piernas',
    description: null,
    estimatedDurationMinutes: 45,
    version: 2,
    blocks: const [],
  );
  @override
  Future<TrainerClient> self() async => planningPerson('self');
  @override
  Future<List<Map<String, dynamic>>> schedule(
    String clientId,
    DateTime day,
  ) async => [];
  @override
  Future<void> assign({
    required String operationId,
    required String relationId,
    required String templateId,
    required DateTime date,
    required String note,
  }) async {
    assigned.add({
      'operation': operationId,
      'relation': relationId,
      'template': templateId,
      'date': appointmentDay(date),
      'note': note,
    });
    if (failAssignment) {
      failAssignment = false;
      throw StateError('respuesta incierta');
    }
  }

  @override
  Future<void> move(
    String operationId,
    CoachAssignment previous,
    DateTime day,
  ) async {
    moved.add({
      'operation': operationId,
      'revision': previous.planningRevision ?? 0,
      'date': appointmentDay(day),
    });
  }

  @override
  Future<void> withdraw(String id) async {
    withdrawn.add(id);
  }

  @override
  Future<CoachPrivateNotes> notes(String id) async => const CoachPrivateNotes(
    notes: 'Mantener técnica',
    goal: 'Coordinar fuerza y carrera',
    revision: 7,
    canEdit: true,
  );
  @override
  Future<void> saveNotes(
    String operationId,
    String clientId,
    CoachPrivateNotes previous,
    String notes,
    String goal,
  ) async {
    noteWrites.add({
      'operation': operationId,
      'client': clientId,
      'revision': previous.revision,
      'notes': notes,
      'goal': goal,
    });
  }

  @override
  Future<List<CoachExerciseReference>> exercises({
    required bool official,
  }) async => [
    CoachExerciseReference(
      id: 'exercise',
      name: official ? 'Dominada oficial' : 'Mi dominada',
      official: official,
      description: 'Extiende los brazos.',
    ),
  ];
  @override
  Future<List<TrainerFollowupFormVersion>> forms() async => [
    TrainerFollowupFormVersion(
      formId: 'family',
      versionId: 'form',
      revision: 1,
      title: 'Seguimiento semanal',
      questions: [
        TrainerFollowupQuestion(
          id: 'molestias',
          position: 0,
          prompt: '¿Tienes molestias?',
          type: TrainerFollowupQuestionType.yesNo,
        ),
      ],
    ),
  ];
  @override
  Future<void> sendForm(
    String id,
    String relation,
    String form,
    DateTime date,
  ) async {
    sentForms.add({
      'operation': id,
      'relation': relation,
      'form': form,
      'date': appointmentDay(date),
    });
  }

  @override
  Future<List<TrainerFormAssignment>> formAssignments(
    String clientId, {
    TrainerFormAssignment? before,
  }) async => before == null ? [await formSubmission('form-assignment')] : [];
  @override
  Future<TrainerFormAssignment> formSubmission(String id) async =>
      TrainerFormAssignment.fromJson({
        'id': id,
        'client_id': 'isabel',
        'relation_id': 'relation',
        'family_id': 'family',
        'form_id': 'form',
        'version': 1,
        'content': TrainerFollowupCodec.encode((await forms()).single),
        'due_date': '2026-11-01',
        'created_at': '2026-10-30',
        'submitted_at': '2026-10-30',
        'can_respond': false,
        'answers': {'molestias': false},
      });
}

class FakeCoachAppointments implements TrainerAppointmentRepository {
  final saved = <AppointmentDraft>[];
  int cancelled = 0;
  bool failCancel = false;
  List<TrainerAppointment> items = [];
  TrainerAppointment row([AppointmentDraft? value]) {
    final day = value?.day ?? DateTime.now(), minute = value?.minute ?? 570;
    final local = DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
    return TrainerAppointment.fromJson({
      'id': value?.id ?? 'appointment',
      'relation_id': 'relation',
      'trainer_id': 'javier',
      'client_id': 'isabel',
      'trainer_name': 'Javier',
      'client_name': 'Isabel Rodríguez Fernández',
      'title': value?.title ?? 'Revisión presencial',
      'starts_at': local.toUtc().toIso8601String(),
      'local_start': local.toIso8601String(),
      'duration_minutes': value?.durationMinutes ?? 60,
      'timezone': value?.timezone ?? 'Europe/Madrid',
      'location': value?.location ?? 'Pista',
      'status': 'scheduled',
      'revision': 1,
      'suggested_reminder': 0,
      'student_reminder': 0,
      'reminder_revision': 0,
      'editable': true,
      'can_remind': true,
    });
  }

  @override
  Future<AppointmentPage> list({
    DateTime? from,
    DateTime? to,
    TrainerAppointment? after,
    bool history = false,
  }) async => AppointmentPage(after == null ? items : []);
  @override
  Future<TrainerAppointment> get(String id) async => row();
  @override
  Future<AppointmentSaveResult> save(
    AppointmentDraft value, {
    bool allowOverlap = false,
  }) async {
    saved.add(value);
    return AppointmentSaveResult(appointment: row(value));
  }

  @override
  Future<AppointmentSaveResult> move(
    TrainerAppointment value,
    DateTime day,
    int minute, {
    bool allowOverlap = false,
  }) async =>
      save(AppointmentDraft.fromAppointment(value, day: day, minute: minute));
  @override
  Future<TrainerAppointment> cancel(TrainerAppointment value) async {
    cancelled++;
    if (failCancel) {
      failCancel = false;
      throw StateError('No confirmado');
    }
    return value;
  }

  @override
  Future<TrainerAppointment> reminder(
    TrainerAppointment value,
    int minutes,
  ) async => value;
}
