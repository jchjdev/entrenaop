import '../domain/coach_workspace_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/workout_template_query.dart';

import '../domain/coach_planning_repository.dart';

class SupabaseCoachPlanningRepository implements CoachPlanningRepository {
  const SupabaseCoachPlanningRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(client, owner, name, params: params);
  Map<String, dynamic> _row(dynamic v) => Map<String, dynamic>.from(v as Map);
  void _identity() {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<List<CoachLibrarySession>> sessions({
    CoachLibrarySession? before,
  }) async =>
      (await _rpc('list_trainer_workouts', {
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map(
            (r) => CoachLibrarySession(
              id: r['id'] as String,
              name: r['name'] as String,
              version: r['version'] as int,
              isRunning: r['is_running'] == true,
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
          )
          .toList();
  @override
  Future<WorkoutTemplate> template(String id) async {
    // La fachada autoriza la biblioteca; la lectura completa sigue sometida a
    // RLS y se restringe expresamente al contenido privado de esta cuenta.
    final status = _row(
      await _rpc('get_my_trainer_account_status', {'p_expected_owner': owner}),
    );
    if (status['enabled'] != true) {
      throw StateError('Acceso profesional inactivo.');
    }
    _identity();
    final row = await client
        .from('workout_templates')
        .select(workoutTemplateSelect)
        .eq('id', id)
        .eq('owner_user_id', owner)
        .eq('origin', 'coach')
        .eq('status', 'published')
        .single();
    _identity();
    return WorkoutTemplateModel.fromJson(row);
  }

  @override
  Future<TrainerClient> self() async {
    await _rpc('ensure_trainer_self_client', {'p_expected_owner': owner});
    final row = _row(
      await _rpc('get_trainer_client_workspace', {'p_client_id': owner}),
    );
    return TrainerClient.fromJson(_row(row['client']));
  }

  @override
  Future<void> assign({
    required String operationId,
    required String relationId,
    required String templateId,
    required DateTime date,
    required String note,
  }) async {
    if (note.trim().length > 500) {
      throw const FormatException('La nota admite hasta 500 caracteres.');
    }
    await _rpc('assign_trainer_workout', {
      'p_id': operationId,
      'p_relation_id': relationId,
      'p_template_id': templateId,
      'p_date': appointmentDay(date),
      'p_note': note.trim(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> schedule(
    String clientId,
    DateTime day,
  ) async => (await _rpc('preview_trainer_schedule', {
    'p_client_id': clientId,
    'p_from': appointmentDay(day),
    'p_to': appointmentDay(day),
  }) as List).map(_row).toList();
  @override
  Future<void> withdraw(String assignmentId) async {
    await _rpc('cancel_trainer_assignment', {'p_id': assignmentId});
  }

  @override
  Future<void> move(
    String operationId,
    CoachAssignment previous,
    DateTime day,
  ) async {
    if (previous.planningRevision == null ||
        previous.status != 'planned' ||
        previous.executionId != null) {
      throw StateError(
        'Actualiza la pauta; solo se mueven sesiones pendientes sin iniciar.',
      );
    }
    await _rpc('change_trainer_assignment', {
      'p_operation_id': operationId,
      'p_id': previous.id,
      'p_expected_revision': previous.planningRevision,
      'p_date': appointmentDay(day),
      'p_note': previous.note,
      'p_recipe': null,
    });
  }

  @override
  Future<CoachPrivateNotes> notes(String clientId) async {
    final row = _row(
      await _rpc('get_trainer_client_workspace', {'p_client_id': clientId}),
    );
    final n = _row(row['notes']);
    return CoachPrivateNotes(
      notes: n['notes'] as String,
      goal: n['goal'] as String,
      revision: n['revision'] as int,
      canEdit: row['can_edit_notes'] == true,
    );
  }

  @override
  Future<void> saveNotes(
    String operationId,
    String clientId,
    CoachPrivateNotes previous,
    String notes,
    String goal,
  ) async {
    if (!previous.canEdit ||
        notes.trim().length > 2000 ||
        goal.trim().length > 500) {
      throw const FormatException(
        'Revisa el permiso y la longitud de las notas.',
      );
    }
    await _rpc('save_trainer_client_notes', {
      'p_operation_id': operationId,
      'p_client_id': clientId,
      'p_expected_revision': previous.revision,
      'p_notes': notes.trim(),
      'p_goal': goal.trim(),
    });
  }

  @override
  TrainerAppointmentRepository get appointments =>
      SupabaseTrainerAppointmentRepository(client, owner, forTrainer: true);
  @override
  Future<List<TrainerFollowupFormVersion>> forms() async =>
      (await _rpc('list_trainer_forms', {}) as List)
          .map((r) => TrainerFollowupCodec.decode(_row(r)))
          .toList();
  @override
  Future<void> sendForm(
    String operationId,
    String relationId,
    String formId,
    DateTime dueDate,
  ) async {
    await _rpc('assign_trainer_form', {
      'p_operation_id': operationId,
      'p_relation_id': relationId,
      'p_form_id': formId,
      'p_due_date': appointmentDay(dueDate),
    });
  }

  @override
  Future<List<TrainerFormAssignment>> formAssignments(
    String clientId, {
    TrainerFormAssignment? before,
  }) async => (await _rpc('list_trainer_form_assignments', {
    'p_client_id': clientId,
    'p_before_at': before?.createdAt.toUtc().toIso8601String(),
    'p_before_id': before?.id,
  }) as List).map((r) => TrainerFormAssignment.fromJson(_row(r))).toList();
  @override
  Future<TrainerFormAssignment> formSubmission(String id) async =>
      TrainerFormAssignment.fromJson(
        _row(
          await _rpc('get_trainer_form_submission', {'p_assignment_id': id}),
        ),
      );

  @override
  Future<List<CoachExerciseReference>> exercises({
    required bool official,
  }) async {
    final status = _row(
      await _rpc('get_my_trainer_account_status', {'p_expected_owner': owner}),
    );
    if (status['enabled'] != true) {
      throw StateError('Acceso profesional inactivo.');
    }
    final rows = <Map<String, dynamic>>[];
    if (official) {
      for (var offset = 0; ; offset += 500) {
        _identity();
        final batch = await client
            .from('exercises')
            .select('id,name,description,video_url,thumbnail_url,image_path')
            .eq('is_public', true)
            .eq('origin', 'system')
            .order('id')
            .range(offset, offset + 499);
        _identity();
        rows.addAll(batch);
        if (batch.length < 500) {
          break;
        }
      }
    } else {
      rows.addAll((await _rpc('list_trainer_exercises', {}) as List).map(_row));
    }
    final signed = <String, String>{};
    final paths = rows
        .map((r) => r['image_path'])
        .whereType<String>()
        .toSet()
        .toList();
    if (!official) {
      for (var i = 0; i < paths.length; i += 100) {
        _identity();
        final urls = await client.storage
            .from('trainer-exercise-images')
            .createSignedUrlsResult(
              paths.sublist(i, i + 100 > paths.length ? paths.length : i + 100),
              900,
            );
        _identity();
        for (final url in urls.whereType<SignedUrlSuccess>()) {
          signed[url.path] = url.signedUrl;
        }
      }
    }
    return rows.map((r) {
      final path = r['image_path'] as String?;
      return CoachExerciseReference(
        id: r['id'] as String,
        name: r['name'] as String,
        official: official,
        description: r['description'] as String? ?? '',
        videoUrl: r['video_url'] as String?,
        imageUrl: path == null
            ? r['thumbnail_url'] as String?
            : official
            ? client.storage.from('exercise-images-public').getPublicUrl(path)
            : signed[path],
      );
    }).toList();
  }
}
