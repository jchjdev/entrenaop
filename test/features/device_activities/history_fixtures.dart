import 'package:device_activity_core/device_activity_core.dart';
import 'package:entrenaop/features/device_activities/domain/running_history.dart';

const ownerA = '10000000-0000-0000-0000-000000000001';
const ownerB = '10000000-0000-0000-0000-000000000002';
const connectionId = '20000000-0000-0000-0000-000000000001';
const externalId = 'AAAAAAAA-0000-0000-0000-000000000001';
final fixtureNow = DateTime.utc(2026, 1, 7, 12);
RunningHistoryConnection connection({
  String owner = ownerA,
  int generation = 0,
}) => RunningHistoryConnection(
  id: connectionId,
  ownerId: owner,
  channel: ActivityChannel.appleHealth,
  generation: generation,
);
ExternalActivity activity({
  String owner = ownerA,
  String revision = 'fixture-A',
  double? distance = 5000.125,
  Duration? timer = const Duration(microseconds: 1700812345),
  String id = externalId,
}) => ExternalActivity(
  identity: ActivityIdentity(
    ownerId: owner,
    channel: ActivityChannel.appleHealth,
    accountScope: 'ephemeral-read',
    externalId: id,
  ),
  revision: ActivityRevision(revision),
  receivedAtUtc: fixtureNow,
  sport: ActivitySport.running,
  startedAtUtc: fixtureNow.subtract(const Duration(microseconds: 1800000123)),
  endedAtUtc: fixtureNow,
  writerApplication: 'com.garmin.connect.mobile',
  metrics: ActivityMetrics(
    elapsed: const Duration(microseconds: 1800000123),
    timer: timer,
    distanceMeters: distance,
  ),
);
RunningHistoryItem saved({
  ExternalActivity? run,
  String hashCharacter = 'a',
  int generation = 0,
}) => RunningHistoryItem(
  id: '30000000-0000-0000-0000-000000000001',
  activity: projectRunningActivity(
    run ?? activity(),
    connection(generation: generation),
  ),
  snapshotHash: hashCharacter * 64,
  savedAtUtc: fixtureNow,
);
Map<String, dynamic> connectionJson({String owner = ownerA}) => {
  'id': connectionId,
  'owner_id': owner,
  'channel': 'apple_health',
  'generation': 0,
};
Map<String, dynamic> savedJson() => {
  'id': '30000000-0000-0000-0000-000000000001',
  'owner_id': ownerA,
  'connection_id': connectionId,
  'external_id': externalId.toLowerCase(),
  'normalizer_version': 1,
  'source_revision': 'fixture-A',
  'snapshot_hash': 'a' * 64,
  'started_at': activity().startedAtUtc!.toIso8601String(),
  'ended_at': fixtureNow.toIso8601String(),
  'elapsed_micros': 1800000123,
  'timer_micros': 1700812345,
  'distance_meters': 5000.125,
  'source_modified_at': null,
  'start_offset_seconds': null,
  'end_offset_seconds': null,
  'time_zone_id': null,
  'device_brand': null,
  'writer_application': 'com.garmin.connect.mobile',
  'first_received_at': fixtureNow.toIso8601String(),
  'accepted_at': fixtureNow.toIso8601String(),
};
