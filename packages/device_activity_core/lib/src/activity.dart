import 'activity_problem.dart';

enum ActivityChannel {
  appleHealth,
  healthConnect,
  garmin,
  coros,
  suunto,
  huawei,
}

enum ActivitySport { running, other }

enum ActivityTimeBasis { elapsed, timer, moving }

enum ActivitySegmentKind { unknown, automaticLap, manualLap, workoutStep }

enum ActivityIssue {
  missingSport,
  notRunning,
  missingStart,
  missingEnd,
  invertedInterval,
  negativeDuration,
  invalidDistance,
  invalidHeartRate,
  invalidOffset,
  invalidSegment,
}

final class ActivityIdentity {
  ActivityIdentity({
    required this.ownerId,
    required this.channel,
    required this.accountScope,
    required this.externalId,
  }) {
    requireIdentifier(ownerId, 'ownerId');
    requireIdentifier(accountScope, 'accountScope');
    requireIdentifier(externalId, 'externalId');
  }

  final String ownerId;
  final ActivityChannel channel;
  final String accountScope;
  final String externalId;

  @override
  bool operator ==(Object other) =>
      other is ActivityIdentity &&
      ownerId == other.ownerId &&
      channel == other.channel &&
      accountScope == other.accountScope &&
      externalId == other.externalId;

  @override
  int get hashCode => Object.hash(ownerId, channel, accountScope, externalId);
}

/// La revisión es opaca. Su orden solo se conoce con una fecha del origen.
final class ActivityRevision {
  ActivityRevision(this.token, {this.modifiedAtUtc}) {
    requireIdentifier(token, 'revision');
    if (modifiedAtUtc case final timestamp?) requireUtc(timestamp);
  }

  final String token;
  final DateTime? modifiedAtUtc;

  @override
  bool operator ==(Object other) =>
      other is ActivityRevision &&
      token == other.token &&
      modifiedAtUtc == other.modifiedAtUtc;

  @override
  int get hashCode => Object.hash(token, modifiedAtUtc);
}

final class ActivityLocalDate {
  ActivityLocalDate(this.year, this.month, this.day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError('Fecha local inválida');
    }
  }

  /// El offset pertenece al instante de inicio, no al teléfono o al servidor.
  factory ActivityLocalDate.fromInstant(DateTime utc, Duration offset) {
    requireUtc(utc);
    if (offset.abs() >= const Duration(days: 1)) {
      throw ArgumentError('Offset inválido');
    }
    final local = utc.add(offset);
    return ActivityLocalDate(local.year, local.month, local.day);
  }

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is ActivityLocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

final class ActivityMetrics {
  const ActivityMetrics({
    this.elapsed,
    this.timer,
    this.moving,
    this.distanceMeters,
    this.averageHeartRateBpm,
    this.maxHeartRateBpm,
  });

  final Duration? elapsed;
  final Duration? timer;
  final Duration? moving;
  final double? distanceMeters;
  final double? averageHeartRateBpm;
  final double? maxHeartRateBpm;

  Set<ActivityIssue> get issues => Set.unmodifiable({
    if ([elapsed, timer, moving].any((value) => value?.isNegative ?? false))
      ActivityIssue.negativeDuration,
    if (!_nonNegativeFinite(distanceMeters)) ActivityIssue.invalidDistance,
    if (!_nonNegativeFinite(averageHeartRateBpm) ||
        !_nonNegativeFinite(maxHeartRateBpm))
      ActivityIssue.invalidHeartRate,
  });

  Duration? durationUsing(ActivityTimeBasis basis) => switch (basis) {
    ActivityTimeBasis.elapsed => elapsed,
    ActivityTimeBasis.timer => timer,
    ActivityTimeBasis.moving => moving,
  };

  PaceMeasurement? paceUsing(ActivityTimeBasis basis) {
    final distance = distanceMeters;
    final time = durationUsing(basis);
    if (issues.isNotEmpty ||
        distance == null ||
        distance <= 0 ||
        time == null ||
        time.inMicroseconds <= 0) {
      return null;
    }
    final pace =
        time.inMicroseconds / Duration.microsecondsPerSecond * 1000 / distance;
    return pace.isFinite ? PaceMeasurement(pace, basis) : null;
  }

  Object get _values => (
    elapsed,
    timer,
    moving,
    distanceMeters,
    averageHeartRateBpm,
    maxHeartRateBpm,
  );

  bool sameAs(ActivityMetrics other) => _values == other._values;
}

final class PaceMeasurement {
  const PaceMeasurement(this.secondsPerKm, this.basis);

  final double secondsPerKm;
  final ActivityTimeBasis basis;
}

final class ActivitySegment {
  ActivitySegment({
    required this.index,
    required this.startedAtUtc,
    required this.endedAtUtc,
    required this.kind,
    this.metrics = const ActivityMetrics(),
  }) {
    requireUtc(startedAtUtc);
    requireUtc(endedAtUtc);
  }

  final int index;
  final DateTime startedAtUtc;
  final DateTime endedAtUtc;
  final ActivitySegmentKind kind;
  final ActivityMetrics metrics;

  bool sameAs(ActivitySegment other) =>
      index == other.index &&
      startedAtUtc == other.startedAtUtc &&
      endedAtUtc == other.endedAtUtc &&
      kind == other.kind &&
      metrics.sameAs(other.metrics);
}

sealed class ActivityChange {
  const ActivityChange();

  ActivityIdentity get identity;
  ActivityRevision get revision;
  bool sameContentAs(ActivityChange other);
}

final class ExternalActivity extends ActivityChange {
  ExternalActivity({
    required this.identity,
    required this.revision,
    required this.receivedAtUtc,
    this.sport,
    this.startedAtUtc,
    this.endedAtUtc,
    this.startUtcOffset,
    this.endUtcOffset,
    this.timeZoneId,
    this.deviceBrand,
    this.writerApplication,
    this.upstreamIdentity,
    this.metrics = const ActivityMetrics(),
    Iterable<ActivitySegment> segments = const [],
  }) : segments = List.unmodifiable(segments) {
    requireUtc(receivedAtUtc);
    if (startedAtUtc case final start?) requireUtc(start);
    if (endedAtUtc case final end?) requireUtc(end);
    if (upstreamIdentity case final upstream?) {
      if (upstream.ownerId != identity.ownerId) {
        throw const ActivityException(ActivityProblem.wrongOwner);
      }
    }
  }

  @override
  final ActivityIdentity identity;
  @override
  final ActivityRevision revision;
  final DateTime receivedAtUtc;
  final ActivitySport? sport;
  final DateTime? startedAtUtc;
  final DateTime? endedAtUtc;
  final Duration? startUtcOffset;
  final Duration? endUtcOffset;
  final String? timeZoneId;
  final String? deviceBrand;
  final String? writerApplication;
  final ActivityIdentity? upstreamIdentity;
  final ActivityMetrics metrics;
  final List<ActivitySegment> segments;

  Set<ActivityIssue> get issues {
    final start = startedAtUtc;
    final end = endedAtUtc;
    final indices = <int>{};
    return Set.unmodifiable({
      ...metrics.issues,
      if (sport == null) ActivityIssue.missingSport,
      if (sport == ActivitySport.other) ActivityIssue.notRunning,
      if (start == null) ActivityIssue.missingStart,
      if (end == null) ActivityIssue.missingEnd,
      if (start != null && end != null && end.isBefore(start))
        ActivityIssue.invertedInterval,
      if ([startUtcOffset, endUtcOffset].any(
        (offset) => offset != null && offset.abs() >= const Duration(days: 1),
      ))
        ActivityIssue.invalidOffset,
      for (final segment in segments)
        if (segment.index < 0 ||
            !indices.add(segment.index) ||
            segment.endedAtUtc.isBefore(segment.startedAtUtc) ||
            (start != null && segment.startedAtUtc.isBefore(start)) ||
            (end != null && segment.endedAtUtc.isAfter(end)) ||
            segment.metrics.issues.isNotEmpty)
          ActivityIssue.invalidSegment,
    });
  }

  ActivityLocalDate? get localStartDate {
    final start = startedAtUtc;
    final offset = startUtcOffset;
    if (start == null ||
        offset == null ||
        offset.abs() >= const Duration(days: 1)) {
      return null;
    }
    return ActivityLocalDate.fromInstant(start, offset);
  }

  @override
  bool sameContentAs(ActivityChange other) =>
      other is ExternalActivity &&
      identity == other.identity &&
      revision == other.revision &&
      (
            sport,
            startedAtUtc,
            endedAtUtc,
            startUtcOffset,
            endUtcOffset,
            timeZoneId,
            deviceBrand,
            writerApplication,
            upstreamIdentity,
          ) ==
          (
            other.sport,
            other.startedAtUtc,
            other.endedAtUtc,
            other.startUtcOffset,
            other.endUtcOffset,
            other.timeZoneId,
            other.deviceBrand,
            other.writerApplication,
            other.upstreamIdentity,
          ) &&
      metrics.sameAs(other.metrics) &&
      segments.length == other.segments.length &&
      Iterable<int>.generate(segments.length)
          .every((index) => segments[index].sameAs(other.segments[index]));
}

final class ActivityDeletion extends ActivityChange {
  const ActivityDeletion({required this.identity, required this.revision});

  @override
  final ActivityIdentity identity;
  @override
  final ActivityRevision revision;

  @override
  bool sameContentAs(ActivityChange other) =>
      other is ActivityDeletion &&
      identity == other.identity &&
      revision == other.revision;
}

bool _nonNegativeFinite(double? value) =>
    value == null || (value.isFinite && value >= 0);
