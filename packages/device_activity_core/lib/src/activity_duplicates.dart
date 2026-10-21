import 'activity.dart';
import 'activity_problem.dart';

enum DuplicateEvidence { sharedOrigin, similarMeasurement }

final class ActivityDuplicateCandidate {
  const ActivityDuplicateCandidate({
    required this.left,
    required this.right,
    required this.evidence,
    required this.policyVersion,
  });

  final ActivityIdentity left;
  final ActivityIdentity right;
  final DuplicateEvidence evidence;
  final String policyVersion;
}

/// Las tolerancias las decide una política versionada del producto. Aquí no se
/// inventan umbrales deportivos ni se convierte una coincidencia en una fusión.
final class FindActivityDuplicates {
  FindActivityDuplicates({
    required this.policyVersion,
    required this.startTolerance,
    required this.durationTolerance,
    required this.distanceToleranceMeters,
    required this.timeBasis,
  }) {
    requireIdentifier(policyVersion, 'policyVersion');
    if (startTolerance.isNegative ||
        durationTolerance.isNegative ||
        !distanceToleranceMeters.isFinite ||
        distanceToleranceMeters < 0) {
      throw ArgumentError('Tolerancias inválidas');
    }
  }

  final Duration startTolerance;
  final String policyVersion;
  final Duration durationTolerance;
  final double distanceToleranceMeters;
  final ActivityTimeBasis timeBasis;

  ActivityDuplicateCandidate? compare(
    ExternalActivity left,
    ExternalActivity right,
  ) {
    if (left.identity.ownerId != right.identity.ownerId ||
        left.identity == right.identity ||
        left.issues.isNotEmpty ||
        right.issues.isNotEmpty) {
      return null;
    }
    if (left.upstreamIdentity == right.identity ||
        right.upstreamIdentity == left.identity ||
        (left.upstreamIdentity != null &&
            left.upstreamIdentity == right.upstreamIdentity)) {
      return ActivityDuplicateCandidate(
        left: left.identity,
        right: right.identity,
        evidence: DuplicateEvidence.sharedOrigin,
        policyVersion: policyVersion,
      );
    }
    final leftTime = left.metrics.durationUsing(timeBasis);
    final rightTime = right.metrics.durationUsing(timeBasis);
    final leftDistance = left.metrics.distanceMeters;
    final rightDistance = right.metrics.distanceMeters;
    if (leftTime == null ||
        rightTime == null ||
        leftDistance == null ||
        rightDistance == null ||
        left.startedAtUtc!.difference(right.startedAtUtc!).abs() >
            startTolerance ||
        (leftTime - rightTime).abs() > durationTolerance ||
        (leftDistance - rightDistance).abs() > distanceToleranceMeters) {
      return null;
    }
    return ActivityDuplicateCandidate(
      left: left.identity,
      right: right.identity,
      evidence: DuplicateEvidence.similarMeasurement,
      policyVersion: policyVersion,
    );
  }
}
