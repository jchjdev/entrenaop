import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/workout_template.dart';

import 'trainer_agenda_page.dart';
import 'trainer_program_repository.dart';
import 'trainer_workout_repository.dart';

Map<String, dynamic> _json(Object? value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> _rows(Object? value) =>
    (value as List).map(_json).toList();

class TrainerGroupMember {
  const TrainerGroupMember({
    required this.clientId,
    required this.name,
    this.relationId,
  });
  factory TrainerGroupMember.fromJson(Map<String, dynamic> row) =>
      TrainerGroupMember(
        clientId: row['client_id'] as String,
        name: row['client_name'] as String,
        relationId: row['relation_id'] as String?,
      );
  final String clientId, name;
  final String? relationId;
  bool get active => relationId != null;
}

class TrainerGroup {
  TrainerGroup.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      revision = (row['revision'] as num).toInt(),
      updatedAt = DateTime.parse(row['updated_at'] as String),
      members = List.unmodifiable(
        _rows(row['members']).map(TrainerGroupMember.fromJson),
      );
  final String id, name;
  final int revision;
  final DateTime updatedAt;
  final List<TrainerGroupMember> members;
}

class TrainerBatchRequest {
  TrainerBatchRequest({
    required List<TrainerGroupMember> recipients,
    this.templateId,
    this.date,
    this.programId,
    List<TrainerProgramEntry> entries = const [],
    this.note,
    this.groupId,
    this.groupRevision,
  }) : recipients = List.unmodifiable(recipients),
       entries = List.unmodifiable(entries);
  final List<TrainerGroupMember> recipients;
  final String? templateId, programId, note, groupId;
  final DateTime? date;
  final int? groupRevision;
  final List<TrainerProgramEntry> entries;
  Map<String, dynamic> toParams() => {
    'p_recipients': [
      for (final recipient in recipients)
        {'client_id': recipient.clientId, 'relation_id': recipient.relationId},
    ],
    'p_template_id': templateId,
    'p_date': date == null ? null : agendaDate(date!),
    'p_program_id': programId,
    'p_entries': programId == null
        ? null
        : entries.map((e) => e.toJson()).toList(),
    'p_note': note,
    'p_group_id': groupId,
    'p_group_revision': groupRevision,
  };
}

class TrainerBatchRecipientPreview {
  TrainerBatchRecipientPreview.fromJson(Map<String, dynamic> row)
    : clientId = row['client_id'] as String,
      name = row['client_name'] as String,
      dates = List.unmodifiable(
        (row['dates'] as List).map((v) => DateTime.parse(v as String)),
      ),
      coincidences = List.unmodifiable(
        _rows(row['coincidences'])
            .map((v) => DateTime.parse(v['date'] as String)),
      );
  final String clientId, name;
  final List<DateTime> dates, coincidences;
}

class TrainerBatchPreview {
  TrainerBatchPreview.fromJson(Map<String, dynamic> row)
    : fingerprint = row['fingerprint'] as String,
      assignmentCount = (row['assignment_count'] as num).toInt(),
      recipients = List.unmodifiable(
        _rows(row['preview']).map(TrainerBatchRecipientPreview.fromJson),
      );
  final int assignmentCount;
  final String fingerprint;
  final List<TrainerBatchRecipientPreview> recipients;
}

class TrainerBatchRecipientReceipt {
  TrainerBatchRecipientReceipt.fromJson(Map<String, dynamic> row)
    : clientId = row['client_id'] as String,
      assignmentIds = List.unmodifiable(
        (row['assignment_ids'] as List).cast<String>(),
      );
  final String clientId;
  final List<String> assignmentIds;
}

class TrainerBatchReceipt {
  TrainerBatchReceipt.fromJson(Map<String, dynamic> row)
    : assignmentCount = (row['assignment_count'] as num).toInt(),
      recipients = List.unmodifiable(
        _rows(row['recipients']).map(TrainerBatchRecipientReceipt.fromJson),
      );
  final int assignmentCount;
  final List<TrainerBatchRecipientReceipt> recipients;
}

class TrainerWeekCopyItem {
  TrainerWeekCopyItem.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      clientId = row['client_id'] as String,
      clientName = row['client_name'] as String,
      templateId = row['template_id'] as String,
      templateName = row['template_name'] as String,
      date = DateTime.parse(row['date'] as String),
      targetDate = DateTime.parse(row['target_date'] as String),
      note = row['note'] as String?,
      hasDateCoincidence = row['has_date_coincidence'] == true;
  final String id, clientId, clientName, templateId, templateName;
  final DateTime date, targetDate;
  final String? note;
  final bool hasDateCoincidence;
}

class TrainerWeekCopyPreview {
  TrainerWeekCopyPreview.fromJson(Map<String, dynamic> row)
    : fingerprint = row['fingerprint'] as String,
      excludedCount = (row['excluded_count'] as num).toInt(),
      items = List.unmodifiable(
        _rows(row['items']).map(TrainerWeekCopyItem.fromJson),
      );
  final String fingerprint;
  final int excludedCount;
  final List<TrainerWeekCopyItem> items;
}

class TrainerWeekCopyReceipt {
  TrainerWeekCopyReceipt.fromJson(Map<String, dynamic> row)
    : assignmentCount = (row['assignment_count'] as num).toInt(),
      byClient = Map.unmodifiable(
        _rows(row['assignments']).fold(<String, int>{}, (map, r) {
          final id = r['client_id'] as String;
          map[id] = (map[id] ?? 0) + 1;
          return map;
        }),
      );
  final int assignmentCount;
  final Map<String, int> byClient;
}

abstract class TrainerGroupsRepository {
  Future<List<TrainerGroup>> groups({TrainerGroup? before});
  Future<void> saveGroup({
    required String operationId,
    required String id,
    required int expectedRevision,
    required String name,
    required List<String> clientIds,
  });
  Future<TrainerBatchPreview> previewBatch(TrainerBatchRequest request);
  Future<TrainerBatchReceipt> deliverBatch(
    String operationId,
    TrainerBatchRequest request,
    String fingerprint,
  );
  Future<TrainerWeekCopyPreview> previewWeek(
    DateTime weekStart,
    int offsetDays,
  );
  Future<TrainerWeekCopyReceipt> copyWeek(
    String operationId,
    DateTime weekStart,
    int offsetDays,
    String fingerprint,
  );
  Future<WorkoutTemplate?> template(String id);
}

class SupabaseTrainerGroupsRepository implements TrainerGroupsRepository {
  const SupabaseTrainerGroupsRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    void identity() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('La cuenta ha cambiado.');
      }
    }

    identity();
    final result = await client.rpc(name, params: params);
    identity();
    return result;
  }

  @override
  Future<List<TrainerGroup>> groups({TrainerGroup? before}) async => _rows(
    await _rpc('list_trainer_groups', {
      'p_before_at': before?.updatedAt.toUtc().toIso8601String(),
      'p_before_id': before?.id,
    }),
  ).map(TrainerGroup.fromJson).toList();
  @override
  Future<void> saveGroup({
    required String operationId,
    required String id,
    required int expectedRevision,
    required String name,
    required List<String> clientIds,
  }) async {
    await _rpc('save_trainer_group', {
      'p_operation_id': operationId,
      'p_id': id,
      'p_expected_revision': expectedRevision,
      'p_name': name,
      'p_client_ids': clientIds,
    });
  }

  @override
  Future<TrainerBatchPreview> previewBatch(TrainerBatchRequest request) async =>
      TrainerBatchPreview.fromJson(
        _json(await _rpc('preview_trainer_batch', request.toParams())),
      );
  @override
  Future<TrainerBatchReceipt> deliverBatch(
    String operationId,
    TrainerBatchRequest request,
    String fingerprint,
  ) async => TrainerBatchReceipt.fromJson(
    _json(
      await _rpc('deliver_trainer_batch_reviewed', {
        'p_operation_id': operationId,
        'p_fingerprint': fingerprint,
        ...request.toParams(),
      }),
    ),
  );
  @override
  Future<TrainerWeekCopyPreview> previewWeek(
    DateTime weekStart,
    int offsetDays,
  ) async => TrainerWeekCopyPreview.fromJson(
    _json(
      await _rpc('preview_trainer_week', {
        'p_week_start': agendaDate(weekStart),
        'p_offset_days': offsetDays,
      }),
    ),
  );
  @override
  Future<TrainerWeekCopyReceipt> copyWeek(
    String operationId,
    DateTime weekStart,
    int offsetDays,
    String fingerprint,
  ) async => TrainerWeekCopyReceipt.fromJson(
    _json(
      await _rpc('copy_trainer_week', {
        'p_operation_id': operationId,
        'p_week_start': agendaDate(weekStart),
        'p_offset_days': offsetDays,
        'p_fingerprint': fingerprint,
      }),
    ),
  );
  @override
  Future<WorkoutTemplate?> template(String id) =>
      SupabaseTrainerWorkoutRepository(client, userId).template(id);
}
