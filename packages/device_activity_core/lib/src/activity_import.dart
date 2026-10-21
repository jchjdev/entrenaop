import 'activity.dart';
import 'activity_problem.dart';

const activityImportPolicyVersion = 1;

/// queryAllowed también representa permiso de consulta con lectura no observable
/// (HealthKit). Una página vacía no cambia este estado a denegado.
enum ActivityReadAccess { notRequested, queryAllowed, denied, revoked }

enum ActivityQuarantineReason {
  invalidActivity,
  revisionCollision,
  unknownRevisionOrder,
}

final class ActivityImportScope {
  ActivityImportScope({
    required this.ownerId,
    required this.connectionId,
    required this.channel,
    required this.accountScope,
  }) {
    requireIdentifier(ownerId, 'ownerId');
    requireIdentifier(connectionId, 'connectionId');
    requireIdentifier(accountScope, 'accountScope');
  }

  final String ownerId;
  final String connectionId;
  final ActivityChannel channel;
  final String accountScope;

  bool contains(ActivityIdentity identity) =>
      identity.ownerId == ownerId &&
      identity.channel == channel &&
      identity.accountScope == accountScope;

  @override
  bool operator ==(Object other) =>
      other is ActivityImportScope &&
      ownerId == other.ownerId &&
      connectionId == other.connectionId &&
      channel == other.channel &&
      accountScope == other.accountScope;

  @override
  int get hashCode => Object.hash(ownerId, connectionId, channel, accountScope);
}

final class ActivityImportPage {
  ActivityImportPage({
    required this.operationId,
    required this.scope,
    required this.generation,
    required this.expectedCursor,
    required this.nextCursor,
    required Iterable<ActivityChange> changes,
  }) : changes = List.unmodifiable(changes) {
    requireIdentifier(operationId, 'operationId');
    requireIdentifier(generation, 'generation');
    if (expectedCursor case final cursor?) requireIdentifier(cursor, 'cursor');
    if (nextCursor case final cursor?) requireIdentifier(cursor, 'cursor');
  }

  final String operationId;
  final ActivityImportScope scope;
  final String generation;
  final String? expectedCursor;
  final String? nextCursor;
  final List<ActivityChange> changes;

  bool sameRequestAs(ActivityImportPage other) =>
      operationId == other.operationId &&
      scope == other.scope &&
      generation == other.generation &&
      expectedCursor == other.expectedCursor &&
      nextCursor == other.nextCursor &&
      changes.length == other.changes.length &&
      Iterable<int>.generate(changes.length)
          .every((index) => changes[index].sameContentAs(other.changes[index]));
}

/// Identifica lo que debe poder recuperarse sin guardar payloads en los logs.
final class QuarantinedActivity {
  QuarantinedActivity({
    required this.identity,
    required this.revision,
    required this.reason,
    required Iterable<ActivityIssue> issues,
  }) : issues = Set.unmodifiable(issues);

  final ActivityIdentity identity;
  final ActivityRevision revision;
  final ActivityQuarantineReason reason;
  final Set<ActivityIssue> issues;

  bool sameAs(QuarantinedActivity other) =>
      identity == other.identity &&
      revision == other.revision &&
      reason == other.reason &&
      issues.length == other.issues.length &&
      issues.containsAll(other.issues);
}

final class ActivityImportState {
  ActivityImportState({
    required this.scope,
    required this.generation,
    required this.readAccess,
    this.cursor,
    this.checkpoint = 0,
    Map<ActivityIdentity, ActivityChange> records = const {},
    Iterable<QuarantinedActivity> quarantine = const [],
    Map<String, ActivityImportPage> receipts = const {},
  }) : records = Map.unmodifiable(records),
       quarantine = List.unmodifiable(quarantine),
       receipts = Map.unmodifiable(receipts) {
    requireIdentifier(generation, 'generation');
    if (checkpoint < 0) throw ArgumentError('Checkpoint negativo');
    if (cursor case final value?) requireIdentifier(value, 'cursor');
    for (final entry in records.entries) {
      if (entry.key != entry.value.identity || !scope.contains(entry.key)) {
        throw const ActivityException(ActivityProblem.wrongScope);
      }
    }
    if (this.quarantine.any((item) => !scope.contains(item.identity)) ||
        this.receipts.entries.any(
          (entry) =>
              entry.key != entry.value.operationId ||
              entry.value.scope != scope ||
              entry.value.generation != generation,
        )) {
      throw const ActivityException(ActivityProblem.wrongScope);
    }
  }

  final ActivityImportScope scope;
  final String generation;
  final ActivityReadAccess readAccess;
  final String? cursor;
  final int checkpoint;
  final Map<ActivityIdentity, ActivityChange> records;
  final List<QuarantinedActivity> quarantine;
  final Map<String, ActivityImportPage> receipts;

  /// Una actualización dudosa bloquea nuevas propuestas, pero conserva el dato
  /// anterior y la evidencia ya confirmada hasta resolver la discrepancia.
  Iterable<ExternalActivity> get activities => records.values
      .whereType<ExternalActivity>()
      .where((activity) => activity.issues.isEmpty && !needsRecovery(activity));

  bool needsRecovery(ExternalActivity activity) => quarantine.any((rejection) {
    if (rejection.identity != activity.identity) return false;
    final rejectedTime = rejection.revision.modifiedAtUtc;
    final acceptedTime = activity.revision.modifiedAtUtc;
    return rejectedTime == null ||
        acceptedTime == null ||
        !rejectedTime.isBefore(acceptedTime);
  });
}

final class ActivityImportPlan {
  const ActivityImportPlan({
    required this.expectedCheckpoint,
    required this.nextState,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.stale,
    required this.quarantined,
    this.isReplay = false,
  });

  /// El adaptador debe comprobarlo y persistir TODO nextState atómicamente.
  final int expectedCheckpoint;
  final ActivityImportState nextState;
  final int inserted;
  final int updated;
  final int unchanged;
  final int stale;
  final int quarantined;
  final bool isReplay;
}

/// Calcula una transición inmutable. No consulta red ni simula persistencia.
final class PlanActivityImport {
  const PlanActivityImport();

  ActivityImportPlan call({
    required String ownerId,
    required ActivityImportState current,
    required ActivityImportPage page,
  }) {
    if (ownerId != current.scope.ownerId || ownerId != page.scope.ownerId) {
      throw const ActivityException(ActivityProblem.wrongOwner);
    }
    if (page.scope != current.scope) {
      throw const ActivityException(ActivityProblem.wrongScope);
    }
    if (page.generation != current.generation) {
      throw const ActivityException(ActivityProblem.staleGeneration);
    }
    if (current.readAccess != ActivityReadAccess.queryAllowed) {
      throw const ActivityException(ActivityProblem.authorizationRequired);
    }
    if (page.changes.any((change) => !page.scope.contains(change.identity))) {
      throw const ActivityException(ActivityProblem.wrongScope);
    }

    final receipt = current.receipts[page.operationId];
    if (receipt != null) {
      if (!receipt.sameRequestAs(page)) {
        throw const ActivityException(ActivityProblem.reusedOperation);
      }
      return ActivityImportPlan(
        expectedCheckpoint: current.checkpoint,
        nextState: current,
        inserted: 0,
        updated: 0,
        unchanged: 0,
        stale: 0,
        quarantined: 0,
        isReplay: true,
      );
    }
    if (page.expectedCursor != current.cursor) {
      throw const ActivityException(ActivityProblem.staleCursor);
    }

    final records = Map.of(current.records);
    final quarantine = List.of(current.quarantine);
    var inserted = 0;
    var updated = 0;
    var unchanged = 0;
    var stale = 0;
    var quarantined = 0;

    void reject(ActivityChange change, ActivityQuarantineReason reason) {
      final rejection = QuarantinedActivity(
        identity: change.identity,
        revision: change.revision,
        reason: reason,
        issues: change is ExternalActivity ? change.issues : const [],
      );
      if (!quarantine.any((item) => item.sameAs(rejection))) {
        quarantine.add(rejection);
      }
      quarantined++;
    }

    for (final change in page.changes) {
      if (change is ExternalActivity && change.issues.isNotEmpty) {
        reject(change, ActivityQuarantineReason.invalidActivity);
        continue;
      }
      final previous = records[change.identity];
      if (previous == null) {
        records[change.identity] = change;
        inserted++;
        continue;
      }
      if (previous.revision.token == change.revision.token) {
        if (previous.sameContentAs(change)) {
          unchanged++;
        } else {
          reject(change, ActivityQuarantineReason.revisionCollision);
        }
        continue;
      }

      final oldTime = previous.revision.modifiedAtUtc;
      final newTime = change.revision.modifiedAtUtc;
      if (oldTime == null || newTime == null || oldTime == newTime) {
        reject(change, ActivityQuarantineReason.unknownRevisionOrder);
      } else if (newTime.isBefore(oldTime)) {
        stale++;
      } else {
        records[change.identity] = change;
        updated++;
      }
    }

    return ActivityImportPlan(
      expectedCheckpoint: current.checkpoint,
      nextState: ActivityImportState(
        scope: current.scope,
        generation: current.generation,
        readAccess: current.readAccess,
        cursor: page.nextCursor,
        checkpoint: current.checkpoint + 1,
        records: records,
        quarantine: quarantine,
        receipts: {...current.receipts, page.operationId: page},
      ),
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
      stale: stale,
      quarantined: quarantined,
    );
  }
}
