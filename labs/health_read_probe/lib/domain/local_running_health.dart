import 'package:device_activity_core/device_activity_core.dart';

enum LocalHealthPlatform { appleHealth, healthConnect, unsupported }

enum HealthStoreAvailability {
  available,
  unavailable,
  updateRequired,
  unsupported,
}

enum HealthReadConsent { granted, queryAllowedUnknown, denied }

enum HealthProbeProblem {
  unavailable,
  permissionRequired,
  invalidResponse,
  readFailed,
}

final class HealthProbeException implements Exception {
  const HealthProbeException(this.problem);
  final HealthProbeProblem problem;

  @override
  String toString() => 'HealthProbeException(${problem.name})';
}

final class HealthReadWindow {
  HealthReadWindow({required this.startUtc, required this.endUtc}) {
    if (!startUtc.isUtc ||
        !endUtc.isUtc ||
        !endUtc.isAfter(startUtc) ||
        endUtc.difference(startUtc) > const Duration(days: 7)) {
      throw ArgumentError(
        'La ventana UTC debe ser positiva y de hasta siete días',
      );
    }
  }

  final DateTime startUtc;
  final DateTime endUtc;
}

final class LocalHealthRead {
  LocalHealthRead({
    required Iterable<ExternalActivity> activities,
    required this.rejectedRecords,
    required this.truncated,
  }) : activities = List.unmodifiable(activities);

  final List<ExternalActivity> activities;
  final int rejectedRecords;
  final bool truncated;
}

/// El ensayo no autentica cuentas ni concede acceso a los datos de las apps.
abstract interface class LocalRunningHealth {
  LocalHealthPlatform get platform;
  Future<HealthStoreAvailability> availability();
  Future<HealthReadConsent> requestReadAccess();
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  });
}
