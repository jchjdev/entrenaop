import 'package:device_activity_core/device_activity_core.dart';

import '../domain/running_history.dart';

abstract final class RunningHistoryCodec {
  static String channel(ActivityChannel value) => switch (value) {
    ActivityChannel.appleHealth => 'apple_health',
    ActivityChannel.healthConnect => 'health_connect',
    _ => throw const RunningHistoryException(RunningHistoryProblem.invalidData),
  };
  static ActivityChannel parseChannel(Object? value) => switch (value) {
    'apple_health' => ActivityChannel.appleHealth,
    'health_connect' => ActivityChannel.healthConnect,
    _ => throw const RunningHistoryException(RunningHistoryProblem.invalidData),
  };
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map) _invalid();
    return Map<String, dynamic>.from(value);
  }

  static String string(Object? value) {
    if (value is! String || value.trim().isEmpty) _invalid();
    return value;
  }

  static int integer(Object? value) {
    if (value is! int) _invalid();
    return value;
  }

  static DateTime utc(Object? value) {
    final date = DateTime.tryParse(string(value));
    if (date == null || !date.isUtc) _invalid();
    return date;
  }

  static RunningHistoryConnection connection(
    Object? value,
    String expectedOwner,
  ) {
    final row = object(value);
    final result = RunningHistoryConnection(
      id: string(row['id']),
      ownerId: string(row['owner_id']),
      channel: parseChannel(row['channel']),
      generation: integer(row['generation']),
    );
    if (result.ownerId != expectedOwner) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
    return result;
  }

  static RunningHistoryPage page(Object? value, String expectedOwner) {
    final row = object(value);
    final scope = connection(row['connection'], expectedOwner);
    final rows = row['items'];
    if (rows is! List || rows.length > 100 || row['has_more'] is! bool) {
      _invalid();
    }
    final items = <RunningHistoryItem>[];
    final seen = <String>{};
    for (final raw in rows) {
      final item = object(raw);
      if (item['owner_id'] != expectedOwner ||
          item['connection_id'] != scope.id) {
        throw const RunningHistoryException(
          RunningHistoryProblem.accountChanged,
        );
      }
      final externalId = canonicalRunningExternalId(
        scope.channel,
        string(item['external_id']),
      );
      if (!seen.add(externalId) || integer(item['normalizer_version']) != 1) {
        _invalid();
      }
      Duration? micros(String key) =>
          item[key] == null ? null : Duration(microseconds: integer(item[key]));
      Duration? offset(String key) =>
          item[key] == null ? null : Duration(seconds: integer(item[key]));
      String? optional(String key) =>
          item[key] == null ? null : string(item[key]);
      final distance = item['distance_meters'];
      if (distance != null &&
          (distance is! num || !distance.isFinite || distance < 0)) {
        _invalid();
      }
      final activity = ExternalActivity(
        identity: ActivityIdentity(
          ownerId: expectedOwner,
          channel: scope.channel,
          accountScope: scope.id,
          externalId: externalId,
        ),
        revision: ActivityRevision(
          string(item['source_revision']),
          modifiedAtUtc: item['source_modified_at'] == null
              ? null
              : utc(item['source_modified_at']),
        ),
        receivedAtUtc: utc(item['first_received_at']),
        sport: ActivitySport.running,
        startedAtUtc: utc(item['started_at']),
        endedAtUtc: utc(item['ended_at']),
        startUtcOffset: offset('start_offset_seconds'),
        endUtcOffset: offset('end_offset_seconds'),
        timeZoneId: optional('time_zone_id'),
        deviceBrand: optional('device_brand'),
        writerApplication: optional('writer_application'),
        metrics: ActivityMetrics(
          elapsed: micros('elapsed_micros'),
          timer: micros('timer_micros'),
          distanceMeters: (distance as num?)?.toDouble(),
        ),
      );
      items.add(
        RunningHistoryItem(
          id: string(item['id']),
          activity: activity,
          snapshotHash: string(item['snapshot_hash']),
          savedAtUtc: utc(item['accepted_at']),
        ),
      );
    }
    return RunningHistoryPage(
      connection: scope,
      items: items,
      next: row['has_more'] == true && items.isNotEmpty
          ? RunningHistoryCursor(
              startedAtUtc: items.last.activity.startedAtUtc!,
              id: items.last.id,
            )
          : null,
    );
  }

  static List<Map<String, dynamic>> selections(RunningSaveRequest request) {
    final result = <Map<String, dynamic>>[];
    for (final selection in request.selections) {
      final a = projectRunningActivity(selection.activity, request.connection);
      int? seconds(Duration? offset) {
        if (offset == null) return null;
        if (offset.inMicroseconds % Duration.microsecondsPerSecond != 0) {
          _invalid();
        }
        return offset.inSeconds;
      }

      result.add({
        'external_id': a.identity.externalId,
        'source_revision': a.revision.token,
        'normalizer_version': 1,
        'started_at': a.startedAtUtc!.toIso8601String(),
        'ended_at': a.endedAtUtc!.toIso8601String(),
        'elapsed_micros': a.metrics.elapsed?.inMicroseconds,
        'timer_micros': a.metrics.timer?.inMicroseconds,
        'distance_meters': a.metrics.distanceMeters,
        'source_modified_at': a.revision.modifiedAtUtc?.toIso8601String(),
        'start_offset_seconds': seconds(a.startUtcOffset),
        'end_offset_seconds': seconds(a.endUtcOffset),
        'time_zone_id': a.timeZoneId,
        'device_brand': a.deviceBrand,
        'writer_application': a.writerApplication,
        'expected_snapshot_hash': selection.expectedSnapshotHash,
      });
    }
    result.sort(
      (a, b) =>
          (a['external_id'] as String).compareTo(b['external_id'] as String),
    );
    return result;
  }

  static RunningSaveReceipt receipt(Object? value) {
    final row = object(value);
    final inserted = integer(row['inserted']);
    final updated = integer(row['updated']);
    final unchanged = integer(row['unchanged']);
    if ([inserted, updated, unchanged].any((n) => n < 0) ||
        inserted + updated + unchanged > 200) {
      _invalid();
    }
    return RunningSaveReceipt(
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
    );
  }

  static Never _invalid() =>
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
}
