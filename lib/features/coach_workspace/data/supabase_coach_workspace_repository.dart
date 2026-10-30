import 'package:trainer_access/trainer_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:workout_core/professional_opposition_goal.dart';

import '../domain/coach_workspace_repository.dart';

/// Consume las mismas fachadas que Trainer web, con token y propietario fijados.
class SupabaseCoachWorkspaceRepository implements CoachWorkspaceRepository {
  const SupabaseCoachWorkspaceRepository(this._client, this.owner);
  final SupabaseClient _client;
  final String owner;
  Future<dynamic> _rpc(String name, Map<String, dynamic> args) =>
      authenticatedTrainerRpc(_client, owner, name, params: args);
  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  CoachAssignment _assignment(Map<String, dynamic> row, {String? clientId}) =>
      CoachAssignment(
        id: row['id'] as String,
        templateId: row['template_id'] as String?,
        planningRevision: (row['planning_revision'] as num?)?.toInt(),
        note: row['note'] as String?,
        name: row['template_name'] as String,
        date: DateTime.parse(row['scheduled_date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        clientId: clientId ?? row['client_id'] as String,
        clientName: row['client_name'] as String? ?? '',
        status: row['status'] as String,
        changedAt: DateTime.tryParse(row['result_changed_at'] as String? ?? ''),
        executionId: row['execution_id'] as String?,
        relationId: row['relation_id'] as String?,
      );
  @override
  Future<SharedCalendarPage> sharedCalendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) => SupabaseTrainerSharedCalendarRepository(
    _client,
    owner,
  ).calendar(clientId, from, to, after: after);
  @override
  Future<List<CoachTechniquePending>> pendingTechnique({
    CoachTechniquePending? before,
  }) async =>
      _rows(
            await _rpc('list_trainer_technique_inbox', {
              'p_expected_owner': owner,
              'p_before_at': before?.createdAt.toUtc().toIso8601String(),
              'p_before_id': before?.id,
            }),
          )
          .map(
            (r) => CoachTechniquePending(
              id: r['id'] as String,
              assignmentId: r['assignment_id'] as String,
              clientName: r['client_name'] as String,
              name: r['template_name'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
          )
          .toList();
  @override
  Future<CoachAccount> account() async {
    final row = await _rpc('get_my_trainer_account_status', {
      'p_expected_owner': owner,
    }) as Map;
    return CoachAccount(enabled: row['enabled'] == true);
  }

  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) => SupabaseTrainerRepository(
    _client,
    userId: owner,
  ).clients(state: state, before: before);
  @override
  Future<List<TrainerRelation>> relations(
    String clientId, {
    TrainerRelation? before,
  }) => SupabaseTrainerRepository(
    _client,
    userId: owner,
  ).clientRelations(clientId, before: before);
  @override
  Future<CoachClientDetail> client(String id) async {
    final row =
        await _rpc('get_trainer_client_workspace', {'p_client_id': id}) as Map;
    final goal = await _rpc('get_trainer_client_goal', {
      'p_expected_owner': owner,
      'p_client_id': id,
    });
    return CoachClientDetail(
      TrainerClient.fromJson(Map<String, dynamic>.from(row['client'] as Map)),
      ProfessionalOppositionGoal.fromJson(
        Map<String, dynamic>.from(goal as Map),
      ),
    );
  }

  @override
  Future<CoachAssignment> assignment(String id) async => _assignment(
    Map<String, dynamic>.from(
      await _rpc('get_trainer_assignment', {'p_id': id}) as Map,
    ),
  );
  @override
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  }) async => _rows(
    await _rpc('list_trainer_agenda_filtered', {
      'p_expected_owner': owner,
      'p_visibility': 'current',
      'p_from': _day(from),
      'p_to': _day(to),
      'p_after_date': after == null ? null : _day(after.date),
      'p_after_id': after?.id,
    }),
  ).map((r) => _assignment(r)).toList();
  @override
  Future<List<CoachAssignment>> assignments(
    String clientId, {
    CoachAssignment? before,
  }) async => _rows(
    await _rpc('list_trainer_assignments_filtered', {
      'p_expected_owner': owner,
      'p_visibility': 'current',
      'p_client_id': clientId,
      'p_before_at': before?.createdAt.toUtc().toIso8601String(),
      'p_before_id': before?.id,
    }),
  ).map((r) => _assignment(r, clientId: clientId)).toList();
  @override
  Future<List<CoachAssignment>> reviews({CoachAssignment? before}) async =>
      _rows(
        await _rpc('list_trainer_review_queue', {
          'p_before_at': before?.changedAt?.toUtc().toIso8601String(),
          'p_before_id': before?.id,
        }),
      ).map((r) => _assignment(r)).toList();
  @override
  Future<Map<String, dynamic>?> result(String assignmentId) async {
    final value = await _rpc('get_trainer_assignment_result', {
      'p_id': assignmentId,
    });
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> technique(String assignmentId) async =>
      _rows(
        await _rpc('list_client_technique_videos', {
          'p_assignment_id': assignmentId,
        }),
      );
  @override
  Future<void> review(
    String operation,
    String assignmentId,
    int revision,
    String note,
  ) async {
    await _rpc('mark_trainer_assignment_reviewed', {
      'p_operation_id': operation,
      'p_id': assignmentId,
      'p_seen_revision': revision,
      'p_private_note': note,
    });
  }

  @override
  Future<void> feedback(
    String operation,
    String assetId,
    double second,
    String body,
  ) async {
    await _rpc('add_trainer_video_feedback', {
      'p_operation_id': operation,
      'p_id': assetId,
      'p_second': second,
      'p_body': body,
    });
  }

  @override
  Future<TrainerMessageInbox> inbox() =>
      SupabaseTrainerMessageRepository(_client, owner).inbox();
}
