import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_rpc.dart';

class TrainerCalendarSharing {
  const TrainerCalendarSharing({
    required this.enabled,
    required this.revision,
    required this.activeTrainers,
    required this.maxActiveTrainers,
  });
  factory TrainerCalendarSharing.fromJson(Map<String, dynamic> json) =>
      TrainerCalendarSharing(
        enabled: json['enabled'] == true,
        revision: (json['revision'] as num).toInt(),
        activeTrainers: (json['active_trainers'] as num).toInt(),
        maxActiveTrainers: (json['max_active_trainers'] as num).toInt(),
      );
  final bool enabled;
  final int revision, activeTrainers, maxActiveTrainers;
}

abstract interface class TrainerCalendarSharingRepository {
  Future<TrainerCalendarSharing> get();
  Future<TrainerCalendarSharing> set(bool enabled, int expectedRevision);
}

class SupabaseTrainerCalendarSharingRepository
    implements TrainerCalendarSharingRepository {
  SupabaseTrainerCalendarSharingRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<TrainerCalendarSharing> _call(
    String method,
    Map<String, dynamic> args,
  ) async => TrainerCalendarSharing.fromJson(
    Map<String, dynamic>.from(
      await authenticatedTrainerRpc(
        client,
        userId,
        method,
        params: {'p_expected_owner': userId, ...args},
      ) as Map,
    ),
  );
  @override
  Future<TrainerCalendarSharing> get() =>
      _call('get_my_trainer_calendar_sharing', {});
  @override
  Future<TrainerCalendarSharing> set(bool enabled, int expectedRevision) =>
      _call('set_my_trainer_calendar_sharing', {
        'p_enabled': enabled,
        'p_expected_revision': expectedRevision,
      });
}

class SharedCalendarEntry {
  SharedCalendarEntry.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      date = DateTime.parse(json['scheduled_date'] as String),
      time = json['scheduled_time'] as String?,
      name = json['template_name'] as String,
      minutes = (json['estimated_duration_minutes'] as num?)?.toInt(),
      source = json['source'] as String,
      status = json['status'] as String,
      own = json['is_own'] == true,
      trainerName = json['trainer_name'] as String?,
      relationActive = json['relation_active'] == true,
      running = json['is_running'] == true;
  final String id, name, source, status;
  final String? trainerName, time;
  final DateTime date;
  final int? minutes;
  final bool own, relationActive, running;
}

class SharedCalendarPage {
  SharedCalendarPage.fromJson(Map<String, dynamic> json)
    : shared = json['shared'] == true,
      hasMore = json['has_more'] == true,
      entries = (json['items'] as List)
          .map(
            (e) => SharedCalendarEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      coaches = (json['coaches'] as List)
          .map(
            (e) => '${(e as Map)['name']}${e['is_you'] == true ? ' (tú)' : ''}',
          )
          .toList();
  final bool shared, hasMore;
  final List<SharedCalendarEntry> entries;
  final List<String> coaches;
}

abstract interface class TrainerSharedCalendarRepository {
  Future<SharedCalendarPage> calendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  });
  Future<Map<String, dynamic>> workout(String clientId, String scheduledId);
}

class SupabaseTrainerSharedCalendarRepository
    implements TrainerSharedCalendarRepository {
  SupabaseTrainerSharedCalendarRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  String _day(DateTime value) => value.toIso8601String().substring(0, 10);
  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic> args,
  ) async => Map<String, dynamic>.from(
    await authenticatedTrainerRpc(
      client,
      userId,
      method,
      params: {'p_expected_owner': userId, ...args},
    ) as Map,
  );
  @override
  Future<SharedCalendarPage> calendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async => SharedCalendarPage.fromJson(
    await _call('get_trainer_shared_calendar', {
      'p_client_id': clientId,
      'p_from': _day(from),
      'p_to': _day(to),
      if (after != null) ...{
        'p_after_date': _day(after.date),
        'p_after_id': after.id,
      },
    }),
  );
  @override
  Future<Map<String, dynamic>> workout(String clientId, String scheduledId) =>
      _call('get_trainer_shared_workout', {
        'p_client_id': clientId,
        'p_scheduled_id': scheduledId,
      });
}
