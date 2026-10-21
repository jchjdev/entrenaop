import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

abstract class TrainerFormRepository {
  Future<List<TrainerFollowupFormVersion>> list();
  Future<TrainerFollowupFormVersion> get(String id);
  Future<String> save(
    String operationId,
    TrainerFollowupFormVersion form, {
    String? previousId,
  });
  Future<void> assign(
    String operationId, {
    required String relationId,
    required String formId,
    required DateTime dueDate,
  });
  Future<List<TrainerFormAssignment>> assignments(
    String clientId, {
    TrainerFormAssignment? before,
  });
  Future<TrainerFormAssignment> assignment(String id);
}

class SupabaseTrainerFormRepository implements TrainerFormRepository {
  const SupabaseTrainerFormRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, [Map<String, dynamic>? params]) async {
    _identity();
    final value = await client.rpc(name, params: params);
    _identity();
    return value;
  }

  @override
  Future<List<TrainerFollowupFormVersion>> list() async =>
      (await _rpc('list_trainer_forms') as List)
          .map(
            (r) => TrainerFollowupCodec.decode(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
  @override
  Future<TrainerFollowupFormVersion> get(String id) async =>
      TrainerFollowupCodec.decode(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_form', {'p_id': id}) as Map,
        ),
      );
  @override
  Future<String> save(
    String operationId,
    TrainerFollowupFormVersion form, {
    String? previousId,
  }) async => await _rpc('save_trainer_form', {
    'p_operation_id': operationId,
    'p_previous_id': previousId,
    'p_payload': TrainerFollowupCodec.encode(form),
  }) as String;
  @override
  Future<void> assign(
    String operationId, {
    required String relationId,
    required String formId,
    required DateTime dueDate,
  }) async {
    await _rpc('assign_trainer_form', {
      'p_operation_id': operationId,
      'p_relation_id': relationId,
      'p_form_id': formId,
      'p_due_date':
          '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
    });
  }

  @override
  Future<List<TrainerFormAssignment>> assignments(
    String clientId, {
    TrainerFormAssignment? before,
  }) async =>
      (await _rpc('list_trainer_form_assignments', {
            'p_client_id': clientId,
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map(
            (r) => TrainerFormAssignment.fromJson(
              Map<String, dynamic>.from(r as Map),
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
}
