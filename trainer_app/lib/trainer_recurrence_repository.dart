import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_calendar_date.dart';
import 'trainer_groups_repository.dart';

Map<String, dynamic> _json(Object? value) =>
    Map<String, dynamic>.from(value as Map);

class TrainerRecurrenceRequest {
  TrainerRecurrenceRequest({
    required List<TrainerGroupMember> recipients,
    required this.templateId,
    required this.weekStart,
    required this.weeks,
    required List<int> weekdays,
    this.note,
  }) : recipients = List.unmodifiable(recipients),
       weekdays = List.unmodifiable(weekdays.toList()..sort());
  final List<TrainerGroupMember> recipients;
  final String templateId;
  final DateTime weekStart;
  final int weeks;
  final List<int> weekdays;
  final String? note;
  Map<String, dynamic> toParams() => {
    'p_recipients': [
      for (final member in recipients)
        {'client_id': member.clientId, 'relation_id': member.relationId},
    ],
    'p_template_id': templateId,
    'p_week_start': trainerCalendarDate(weekStart),
    'p_weeks': weeks,
    'p_weekdays': weekdays,
    'p_note': note,
  };
}

class TrainerRecurrencePreview {
  TrainerRecurrencePreview.fromJson(Map<String, dynamic> row)
    : fingerprint = row['fingerprint'] as String,
      batch = TrainerBatchPreview.fromJson(row);
  final String fingerprint;
  final TrainerBatchPreview batch;
}

class TrainerRecurrenceReceipt {
  TrainerRecurrenceReceipt.fromJson(Map<String, dynamic> row)
    : seriesId = row['series_id'] as String,
      batch = TrainerBatchReceipt.fromJson(row);
  final String seriesId;
  final TrainerBatchReceipt batch;
}

class TrainerRecurrence {
  TrainerRecurrence.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      templateName = row['template_name'] as String,
      templateVersion = (row['template_version'] as num).toInt(),
      weekStart = DateTime.parse(row['week_start'] as String),
      weeks = (row['weeks'] as num).toInt(),
      weekdays = List.unmodifiable((row['weekdays'] as List).cast<int>()),
      createdAt = DateTime.parse(row['created_at'] as String),
      assignmentCount = (row['assignment_count'] as num).toInt(),
      pendingCount = (row['pending_count'] as num).toInt();
  final String id, templateName;
  final DateTime weekStart, createdAt;
  final int weeks, templateVersion, assignmentCount, pendingCount;
  final List<int> weekdays;
}

class TrainerRecurrenceWithdrawalItem {
  TrainerRecurrenceWithdrawalItem.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      clientName = row['client_name'] as String,
      date = DateTime.parse(row['date'] as String);
  final String id, clientName;
  final DateTime date;
}

class TrainerRecurrenceWithdrawal {
  TrainerRecurrenceWithdrawal.fromJson(Map<String, dynamic> row)
    : fingerprint = row['fingerprint'] as String,
      excludedCount = (row['excluded_count'] as num).toInt(),
      items = List.unmodifiable(
        (row['items'] as List).map(
          (v) => TrainerRecurrenceWithdrawalItem.fromJson(_json(v)),
        ),
      );
  final String fingerprint;
  final int excludedCount;
  final List<TrainerRecurrenceWithdrawalItem> items;
}

abstract class TrainerRecurrenceRepository {
  Future<List<TrainerRecurrence>> series({TrainerRecurrence? before});
  Future<TrainerRecurrencePreview> preview(TrainerRecurrenceRequest request);
  Future<TrainerRecurrenceReceipt> create(
    String operationId,
    TrainerRecurrenceRequest request,
    String fingerprint,
  );
  Future<TrainerRecurrenceWithdrawal> previewWithdrawal(
    String seriesId,
    DateTime fromDate,
  );
  Future<int> withdraw(
    String operationId,
    String seriesId,
    DateTime fromDate,
    String fingerprint,
  );
}

class SupabaseTrainerRecurrenceRepository
    implements TrainerRecurrenceRepository {
  const SupabaseTrainerRecurrenceRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    void identity() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('La cuenta ha cambiado.');
      }
    }

    identity();
    final value = await client.rpc(name, params: params);
    identity();
    return value;
  }

  @override
  Future<List<TrainerRecurrence>> series({TrainerRecurrence? before}) async =>
      (await _rpc('list_trainer_recurrences', {
        'p_before_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
      }) as List).map((v) => TrainerRecurrence.fromJson(_json(v))).toList();
  @override
  Future<TrainerRecurrencePreview> preview(
    TrainerRecurrenceRequest request,
  ) async => TrainerRecurrencePreview.fromJson(
    _json(await _rpc('preview_trainer_recurrence', request.toParams())),
  );
  @override
  Future<TrainerRecurrenceReceipt> create(
    String operationId,
    TrainerRecurrenceRequest request,
    String fingerprint,
  ) async => TrainerRecurrenceReceipt.fromJson(
    _json(
      await _rpc('create_trainer_recurrence', {
        'p_operation_id': operationId,
        ...request.toParams(),
        'p_fingerprint': fingerprint,
      }),
    ),
  );
  @override
  Future<TrainerRecurrenceWithdrawal> previewWithdrawal(
    String seriesId,
    DateTime fromDate,
  ) async => TrainerRecurrenceWithdrawal.fromJson(
    _json(
      await _rpc('preview_trainer_recurrence_withdrawal', {
        'p_series_id': seriesId,
        'p_from_date': trainerCalendarDate(fromDate),
      }),
    ),
  );
  @override
  Future<int> withdraw(
    String operationId,
    String seriesId,
    DateTime fromDate,
    String fingerprint,
  ) async =>
      (_json(
                await _rpc('withdraw_trainer_recurrence', {
                  'p_operation_id': operationId,
                  'p_series_id': seriesId,
                  'p_from_date': trainerCalendarDate(fromDate),
                  'p_fingerprint': fingerprint,
                }),
              )['cancelled_count']
              as num)
          .toInt();
}
