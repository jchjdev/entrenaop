import 'activity.dart';
import 'activity_problem.dart';

const activityAssociationPolicyVersion = 1;

enum RunningSessionStatus { planned, inProgress, completed, retired }

/// Proyección de una cita existente; no crea otra agenda ni reglas de Trainer.
final class RunningSessionTarget {
  RunningSessionTarget({
    required this.id,
    required this.ownerId,
    required this.templateId,
    required this.templateVersion,
    required this.revision,
    required this.localDate,
    required this.status,
    this.executionId,
    this.resultRevision,
  }) {
    for (final value in [id, ownerId, templateId, revision]) {
      requireIdentifier(value, 'session');
    }
    if (templateVersion < 1) throw ArgumentError('Versión de receta inválida');
    if (executionId case final value?) requireIdentifier(value, 'executionId');
    if (resultRevision case final value?) {
      requireIdentifier(value, 'resultRevision');
    }
  }

  final String id;
  final String ownerId;
  final String templateId;
  final int templateVersion;
  final String revision;
  final ActivityLocalDate localDate;
  final RunningSessionStatus status;
  final String? executionId;
  final String? resultRevision;

  bool sameAs(RunningSessionTarget other) =>
      (
        id,
        ownerId,
        templateId,
        templateVersion,
        revision,
        localDate,
        status,
        executionId,
        resultRevision,
      ) ==
      (
        other.id,
        other.ownerId,
        other.templateId,
        other.templateVersion,
        other.revision,
        other.localDate,
        other.status,
        other.executionId,
        other.resultRevision,
      );
}

/// Es una candidatura por fecha local, nunca una selección o confirmación.
List<RunningSessionTarget> proposeRunningSessions({
  required String ownerId,
  required ExternalActivity activity,
  required Iterable<RunningSessionTarget> targets,
}) {
  _requireActivity(ownerId, activity);
  final date = activity.localStartDate;
  if (date == null) return const [];
  return List.unmodifiable(
    targets.where(
      (target) =>
          target.ownerId == ownerId &&
          target.status != RunningSessionStatus.retired &&
          target.localDate == date,
    ),
  );
}

final class ActivityAssociationReview {
  ActivityAssociationReview._({
    required this.operationId,
    required this.primary,
    required Iterable<ExternalActivity> observations,
    required this.target,
  }) : observations = List.unmodifiable(observations);

  final String operationId;
  final ExternalActivity primary;

  /// Alias elegidos expresamente por el titular, nunca por una heurística.
  final List<ExternalActivity> observations;
  final RunningSessionTarget target;

  bool sameRequestAs(ActivityAssociationReview other) =>
      operationId == other.operationId &&
      primary.identity == other.primary.identity &&
      target.sameAs(other.target) &&
      observations.length == other.observations.length &&
      observations.every(
        (observation) => other.observations.any(observation.sameContentAs),
      );
}

ActivityAssociationReview reviewRunningActivity({
  required String ownerId,
  required String operationId,
  required ExternalActivity primary,
  required RunningSessionTarget target,
  Iterable<ExternalActivity> aliases = const [],
}) {
  requireIdentifier(operationId, 'operationId');
  _requireActivity(ownerId, primary);
  _requireSession(ownerId, target);
  final observations = [primary, ...aliases];
  final identities = <ActivityIdentity>{};
  for (final observation in observations) {
    _requireActivity(ownerId, observation);
    if (!identities.add(observation.identity)) {
      throw const ActivityException(ActivityProblem.invalidActivity);
    }
  }
  return ActivityAssociationReview._(
    operationId: operationId,
    primary: primary,
    observations: observations,
    target: target,
  );
}

final class ActivityAssociation {
  ActivityAssociation._(this.review, this.confirmedAtUtc);

  final ActivityAssociationReview review;
  final DateTime confirmedAtUtc;

  String get sessionId => review.target.id;
  String? get executionId => review.target.executionId;
  ActivityIdentity get primaryIdentity => review.primary.identity;
  Iterable<ActivityIdentity> get identities =>
      review.observations.map((observation) => observation.identity);
}

final class ActivityAssociationState {
  ActivityAssociationState({
    required this.ownerId,
    this.checkpoint = 0,
    Iterable<ActivityAssociation> associations = const [],
  }) : associations = List.unmodifiable(associations) {
    requireIdentifier(ownerId, 'ownerId');
    if (checkpoint < 0) throw ArgumentError('Checkpoint negativo');
    final operations = <String>{};
    final sessions = <String>{};
    final identities = <ActivityIdentity>{};
    for (final association in this.associations) {
      if (association.review.target.ownerId != ownerId ||
          association.identities.any(
            (identity) => identity.ownerId != ownerId,
          )) {
        throw const ActivityException(ActivityProblem.wrongOwner);
      }
      if (!operations.add(association.review.operationId)) {
        throw const ActivityException(ActivityProblem.reusedOperation);
      }
      if (!sessions.add(association.sessionId)) {
        throw const ActivityException(ActivityProblem.sessionAlreadyAssociated);
      }
      if (association.identities.any((identity) => !identities.add(identity))) {
        throw const ActivityException(
          ActivityProblem.activityAlreadyAssociated,
        );
      }
    }
  }

  final String ownerId;
  final int checkpoint;
  final List<ActivityAssociation> associations;
}

final class ActivityAssociationPlan {
  const ActivityAssociationPlan({
    required this.expectedCheckpoint,
    required this.nextState,
    required this.association,
    this.isReplay = false,
  });

  final int expectedCheckpoint;
  final ActivityAssociationState nextState;
  final ActivityAssociation association;
  final bool isReplay;
}

/// Confirma solo la asociación. No crea/finaliza ejecuciones ni escribe marcas.
final class ConfirmActivityAssociation {
  const ConfirmActivityAssociation();

  ActivityAssociationPlan call({
    required String ownerId,
    required ActivityAssociationState current,
    required ActivityAssociationReview review,
    required Iterable<ActivityChange> currentObservations,
    required RunningSessionTarget currentTarget,
    required DateTime confirmedAtUtc,
  }) {
    requireUtc(confirmedAtUtc);
    if (ownerId != current.ownerId ||
        ownerId != review.target.ownerId ||
        ownerId != currentTarget.ownerId ||
        review.observations.any((item) => item.identity.ownerId != ownerId)) {
      throw const ActivityException(ActivityProblem.wrongOwner);
    }

    for (final association in current.associations) {
      if (association.review.operationId == review.operationId) {
        if (!association.review.sameRequestAs(review)) {
          throw const ActivityException(ActivityProblem.reusedOperation);
        }
        return ActivityAssociationPlan(
          expectedCheckpoint: current.checkpoint,
          nextState: current,
          association: association,
          isReplay: true,
        );
      }
    }
    _requireSession(ownerId, currentTarget);
    if (!review.target.sameAs(currentTarget)) {
      throw const ActivityException(ActivityProblem.staleReview);
    }
    final observed = <ActivityIdentity, ActivityChange>{};
    for (final observation in currentObservations) {
      if (observation.identity.ownerId != ownerId) {
        throw const ActivityException(ActivityProblem.wrongOwner);
      }
      if (observed.containsKey(observation.identity)) {
        throw const ActivityException(ActivityProblem.invalidActivity);
      }
      observed[observation.identity] = observation;
    }
    for (final reviewed in review.observations) {
      final observation = observed[reviewed.identity];
      if (observation == null || !reviewed.sameContentAs(observation)) {
        throw const ActivityException(ActivityProblem.staleReview);
      }
      _requireActivity(ownerId, reviewed);
    }
    final selectedIdentities = review.observations
        .map((item) => item.identity)
        .toSet();
    for (final association in current.associations) {
      if (association.identities.any(selectedIdentities.contains)) {
        throw const ActivityException(
          ActivityProblem.activityAlreadyAssociated,
        );
      }
      if (association.sessionId == currentTarget.id) {
        throw const ActivityException(ActivityProblem.sessionAlreadyAssociated);
      }
    }
    final association = ActivityAssociation._(review, confirmedAtUtc);
    return ActivityAssociationPlan(
      expectedCheckpoint: current.checkpoint,
      nextState: ActivityAssociationState(
        ownerId: ownerId,
        checkpoint: current.checkpoint + 1,
        associations: [...current.associations, association],
      ),
      association: association,
    );
  }
}

void _requireActivity(String ownerId, ExternalActivity activity) {
  if (activity.identity.ownerId != ownerId) {
    throw const ActivityException(ActivityProblem.wrongOwner);
  }
  if (activity.issues.isNotEmpty) {
    throw const ActivityException(ActivityProblem.invalidActivity);
  }
}

void _requireSession(String ownerId, RunningSessionTarget target) {
  if (target.ownerId != ownerId) {
    throw const ActivityException(ActivityProblem.wrongOwner);
  }
  if (target.status == RunningSessionStatus.retired) {
    throw const ActivityException(ActivityProblem.unavailableSession);
  }
}
