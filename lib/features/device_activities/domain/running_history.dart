import 'package:device_activity_core/device_activity_core.dart';

enum RunningHistoryProblem {
  accountChanged,
  unavailable,
  invalidData,
  conflict,
  historicalRevision,
  revisionCollision,
  operationReused,
  limitReached,
  staleGeneration,
}

final class RunningHistoryException implements Exception {
  const RunningHistoryException(this.problem);
  final RunningHistoryProblem problem;
  @override
  String toString() => 'RunningHistoryException(${problem.name})';
}

final class RunningHistoryConnection {
  RunningHistoryConnection({
    required this.id,
    required this.ownerId,
    required this.channel,
    required this.generation,
  }) {
    if (id.trim().isEmpty ||
        ownerId.trim().isEmpty ||
        generation < 0 ||
        (channel != ActivityChannel.appleHealth &&
            channel != ActivityChannel.healthConnect)) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
  }
  final String id;
  final String ownerId;
  final ActivityChannel channel;
  final int generation;
}

/// El UUID es de un objeto HealthKit: no identifica AppleID ni al propietario.
String canonicalRunningExternalId(ActivityChannel channel, String id) {
  if (channel == ActivityChannel.appleHealth) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
    return id.toLowerCase();
  }
  if (id.trim().isEmpty || id.length > 200) {
    throw const RunningHistoryException(RunningHistoryProblem.invalidData);
  }
  return id;
}

/// Proyección explícita: el ámbito efímero de lectura nunca es la clave guardada.
ExternalActivity projectRunningActivity(
  ExternalActivity activity,
  RunningHistoryConnection connection,
) {
  if (activity.identity.ownerId != connection.ownerId ||
      activity.identity.channel != connection.channel) {
    throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
  }
  if (activity.issues.isNotEmpty ||
      activity.segments.isNotEmpty ||
      activity.upstreamIdentity != null ||
      activity.metrics.moving != null ||
      activity.metrics.averageHeartRateBpm != null ||
      activity.metrics.maxHeartRateBpm != null) {
    throw const RunningHistoryException(RunningHistoryProblem.invalidData);
  }
  return ExternalActivity(
    identity: ActivityIdentity(
      ownerId: connection.ownerId,
      channel: connection.channel,
      accountScope: connection.id,
      externalId: canonicalRunningExternalId(
        connection.channel,
        activity.identity.externalId,
      ),
    ),
    revision: activity.revision,
    receivedAtUtc: activity.receivedAtUtc,
    sport: activity.sport,
    startedAtUtc: activity.startedAtUtc,
    endedAtUtc: activity.endedAtUtc,
    startUtcOffset: activity.startUtcOffset,
    endUtcOffset: activity.endUtcOffset,
    timeZoneId: activity.timeZoneId,
    deviceBrand: activity.deviceBrand,
    writerApplication: activity.writerApplication,
    metrics: activity.metrics,
  );
}

final class RunningHistoryItem {
  RunningHistoryItem({
    required this.id,
    required this.activity,
    required this.snapshotHash,
    required this.savedAtUtc,
  }) {
    if (id.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(snapshotHash) ||
        !savedAtUtc.isUtc ||
        activity.issues.isNotEmpty) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
  }
  final String id;
  final ExternalActivity activity;
  final String snapshotHash;
  final DateTime savedAtUtc;
}

final class RunningHistoryCursor {
  const RunningHistoryCursor({required this.startedAtUtc, required this.id});
  final DateTime startedAtUtc;
  final String id;
}

final class RunningHistoryPage {
  RunningHistoryPage({
    required this.connection,
    required Iterable<RunningHistoryItem> items,
    this.next,
  }) : items = List.unmodifiable(items) {
    if (this.items.any(
      (i) =>
          i.activity.identity.ownerId != connection.ownerId ||
          i.activity.identity.accountScope != connection.id ||
          i.activity.identity.channel != connection.channel,
    )) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
  }
  final RunningHistoryConnection connection;
  final List<RunningHistoryItem> items;
  final RunningHistoryCursor? next;
}

final class ReviewedRunningActivity {
  ReviewedRunningActivity({required this.activity, this.expectedSnapshotHash}) {
    if (expectedSnapshotHash != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedSnapshotHash!)) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
  }
  final ExternalActivity activity;
  final String? expectedSnapshotHash;
}

final class RunningSaveRequest {
  RunningSaveRequest({
    required this.operationId,
    required this.connection,
    required Iterable<ReviewedRunningActivity> selections,
  }) : selections = List.unmodifiable(selections) {
    if (operationId.trim().isEmpty ||
        this.selections.isEmpty ||
        this.selections.length > 200) {
      throw const RunningHistoryException(RunningHistoryProblem.invalidData);
    }
    final ids = <String>{};
    for (final selection in this.selections) {
      final projected = projectRunningActivity(selection.activity, connection);
      if (!ids.add(projected.identity.externalId)) {
        throw const RunningHistoryException(RunningHistoryProblem.invalidData);
      }
    }
  }
  final String operationId;
  final RunningHistoryConnection connection;
  final List<ReviewedRunningActivity> selections;
}

final class RunningSaveReceipt {
  const RunningSaveReceipt({
    required this.inserted,
    required this.updated,
    required this.unchanged,
  });
  final int inserted;
  final int updated;
  final int unchanged;
}

/// Frena el envío tras un await si la cuenta, página o selección ya no son vigentes.
final class RunningOperationFence {
  bool _active = true;
  void cancel() => _active = false;
  void check() {
    if (!_active) {
      throw const RunningHistoryException(RunningHistoryProblem.accountChanged);
    }
  }
}

abstract interface class RunningHistoryRepository {
  String get ownerId;
  Future<RunningHistoryPage> load({RunningHistoryCursor? before});
  Future<RunningSaveReceipt> save(
    RunningSaveRequest request,
    RunningOperationFence fence,
  );
  Future<void> clear({
    required RunningHistoryConnection connection,
    required String operationId,
    required RunningOperationFence fence,
  });
}
