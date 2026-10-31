import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_result.dart';
import 'activity_result_codec.dart';

export 'activity_result_codec.dart' show decodeActivityReview;

class SupabaseActivityResultRepository implements ActivityResultRepository {
  const SupabaseActivityResultRepository(this.client, this.ownerId);
  final SupabaseClient client;
  final String ownerId;
  String _session() {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != ownerId) {
      throw const ActivityResultException('account_changed');
    }
    try {
      return (jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(session.accessToken.split('.')[1]),
              ),
            ),
          ) as Map)['session_id']
          as String;
    } catch (_) {
      throw const ActivityResultException('account_changed');
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, Object?> fields = const {},
  ]) async {
    final session = _session();
    try {
      final response = await client.functions.invoke(
        'garmin-activities',
        body: {
          'action': action,
          'expected_user_id': ownerId,
          'activity_schema_version': 2,
          ...fields,
        },
      );
      if (_session() != session) {
        throw const ActivityResultException('account_changed');
      }
      if (response.status != 200 || response.data is! Map) {
        throw const ActivityResultException('activity_unavailable');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      if (_session() != session) {
        throw const ActivityResultException('account_changed');
      }
      final code = error.details is Map ? (error.details as Map)['code'] : null;
      throw ActivityResultException(
        code is String ? code : 'activity_unavailable',
      );
    } catch (_) {
      if (_session() != session) {
        throw const ActivityResultException('account_changed');
      }
      rethrow;
    }
  }

  @override
  Future<ActivityResultCatalog> load() async {
    final data = await _call('list');
    return ActivityResultCatalog(
      [
        for (final run in data['activities'] as List)
          ReceivedRun(
            run['id'] as String,
            run['revision'] as String,
            run['activity']['name'] as String,
            DateTime.parse(run['activity']['startedAt'] as String),
            (run['activity']['timerSeconds'] as num).toDouble(),
            (run['activity']['distanceMeters'] as num?)?.toDouble() ?? 0,
            run['execution_id'] as String?,
            sport: run['activity']['sport'] as String? ?? 'running',
          ),
      ],
      [
        for (final appointment in data['candidates'] as List)
          RunAppointment(
            appointment['id'] as String,
            appointment['name'] as String,
            appointment['date'] as String,
            sport: appointment['sport'] as String? ?? 'running',
          ),
      ],
      [
        for (final problem in data['problems'] as List)
          problem['error_code'] as String,
      ],
    );
  }

  @override
  Future<ActivityResultReview> preview(
    String activityId,
    String scheduledId,
  ) async => decodeActivityReview(
    await _call('preview', {
      'activity_id': activityId,
      'scheduled_id': scheduledId,
    }),
  );

  @override
  Future<String> confirm(ConfirmActivityResult request) async {
    final data = await _call('confirm', {
      'operation_id': request.operationId,
      'activity_id': request.review.activityId,
      'activity_revision': request.review.activityRevision,
      'scheduled_id': request.review.scheduledId,
      'source_revision': request.review.sourceRevision,
      'rpe': request.rpe,
      'utc_offset_minutes': request.offsetMinutes,
      'mapping': [
        for (final row in request.rows)
          {
            'block_order': row.block,
            'item_order': row.item,
            'set_order': row.set,
            'lap_indices': row.skipped ? const <int>[] : row.laps,
            'recovery_lap_indices': row.skipped
                ? const <int>[]
                : row.recoveryLaps,
            'skipped': row.skipped,
          },
      ],
    });
    return data['execution_id'] as String;
  }
}
