import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

/// Adaptador del alumno; el servidor deriva siempre su identidad y su entrega.
class SupabaseTrainerStudentFormRepository
    implements TrainerStudentFormRepository {
  const SupabaseTrainerStudentFormRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _identity();
    final value = await client.rpc(name, params: params);
    _identity();
    return value;
  }

  @override
  Future<List<TrainerFormAssignment>> mine({
    TrainerFormAssignment? before,
  }) async =>
      (await _rpc('list_my_trainer_forms', {
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map(
            (row) => TrainerFormAssignment.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
  @override
  Future<TrainerFormAssignment> assignment(String id) async =>
      TrainerFormAssignment.fromJson(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_form_submission', {'p_assignment_id': id})
              as Map,
        ),
      );
  @override
  Future<void> submit(
    String operationId,
    TrainerFormAssignment assignment,
    Map<String, Object?> answers,
  ) async {
    final normalized = TrainerFollowupValidator.normalizeSubmission(
      form: assignment.form,
      versionId: assignment.form.versionId,
      answers: answers,
    );
    await _rpc('submit_trainer_form', {
      'p_operation_id': operationId,
      'p_assignment_id': assignment.id,
      'p_answers': normalized.answers,
    });
  }
}
