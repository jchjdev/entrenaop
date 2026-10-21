import 'package:device_activity_core/device_activity_core.dart';
import 'package:test/test.dart';

final instant = DateTime.utc(2026, 10, 21, 8);
final modification = DateTime.utc(2026, 10, 21, 9);

ActivityIdentity identity({
  String owner = 'athlete',
  ActivityChannel channel = ActivityChannel.garmin,
  String account = 'account',
  String id = 'run-1',
}) => ActivityIdentity(
  ownerId: owner,
  channel: channel,
  accountScope: account,
  externalId: id,
);

ExternalActivity running({
  ActivityIdentity? key,
  String revision = 'r1',
  DateTime? modifiedAt,
  bool unknownModificationTime = false,
  DateTime? receivedAt,
  DateTime? start,
  DateTime? end,
  bool missingStart = false,
  bool missingEnd = false,
  ActivitySport? sport = ActivitySport.running,
  Duration? startOffset = const Duration(hours: 2),
  Duration? endOffset,
  ActivityMetrics metrics = const ActivityMetrics(
    elapsed: Duration(seconds: 630),
    timer: Duration(seconds: 600),
    distanceMeters: 2000,
  ),
  Iterable<ActivitySegment> segments = const [],
  ActivityIdentity? upstream,
}) => ExternalActivity(
  identity: key ?? identity(),
  revision: ActivityRevision(
    revision,
    modifiedAtUtc: unknownModificationTime ? null : modifiedAt ?? modification,
  ),
  receivedAtUtc: receivedAt ?? modification,
  startedAtUtc: missingStart ? null : start ?? instant,
  endedAtUtc: missingEnd
      ? null
      : end ?? instant.add(const Duration(minutes: 11)),
  sport: sport,
  startUtcOffset: startOffset,
  endUtcOffset: endOffset,
  metrics: metrics,
  segments: segments,
  upstreamIdentity: upstream,
  deviceBrand: 'Garmin',
  writerApplication: 'Connect',
);

ActivityImportScope scope({
  String owner = 'athlete',
  ActivityChannel channel = ActivityChannel.garmin,
  String account = 'account',
  String connection = 'connection',
}) => ActivityImportScope(
  ownerId: owner,
  connectionId: connection,
  channel: channel,
  accountScope: account,
);

ActivityImportState importState({
  Iterable<ActivityChange> records = const [],
  ActivityReadAccess access = ActivityReadAccess.queryAllowed,
  String generation = 'generation-1',
  String? cursor,
  ActivityImportScope? feed,
}) => ActivityImportState(
  scope: feed ?? scope(),
  generation: generation,
  readAccess: access,
  cursor: cursor,
  records: {for (final record in records) record.identity: record},
);

ActivityImportPage page(
  Iterable<ActivityChange> changes, {
  String operation = 'page-1',
  String generation = 'generation-1',
  String? expectedCursor,
  String? nextCursor = 'cursor-1',
  ActivityImportScope? feed,
}) => ActivityImportPage(
  operationId: operation,
  scope: feed ?? scope(),
  generation: generation,
  expectedCursor: expectedCursor,
  nextCursor: nextCursor,
  changes: changes,
);

RunningSessionTarget target({
  String id = 'session-1',
  String owner = 'athlete',
  String revision = 'schedule-r1',
  int templateVersion = 1,
  String? executionId,
  String? resultRevision,
  ActivityLocalDate? date,
  RunningSessionStatus status = RunningSessionStatus.planned,
}) => RunningSessionTarget(
  id: id,
  ownerId: owner,
  templateId: 'template-1',
  templateVersion: templateVersion,
  revision: revision,
  localDate: date ?? ActivityLocalDate(2026, 10, 21),
  status: status,
  executionId: executionId,
  resultRevision: resultRevision,
);

Matcher hasProblem(ActivityProblem problem) => isA<ActivityException>().having(
  (error) => error.problem,
  'problem',
  problem,
);
