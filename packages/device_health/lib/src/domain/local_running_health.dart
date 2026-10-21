import 'package:device_activity_core/device_activity_core.dart';

enum LocalHealthPlatform { appleHealth, healthConnect, unsupported }

enum HealthStoreAvailability {
  available,
  unavailable,
  updateRequired,
  notIntegrated,
  unsupported,
}

enum HealthReadConsent { granted, queryAllowedUnknown, denied }

enum HealthReadProblem {
  unavailable,
  permissionRequired,
  invalidResponse,
  readFailed,
}

final class HealthReadException implements Exception {
  const HealthReadException(this.problem);
  final HealthReadProblem problem;

  @override
  String toString() => 'HealthReadException(${problem.name})';
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

/// Leer el almacén local no autentica cuentas ni concede acceso de servidor.
abstract interface class LocalRunningHealth {
  LocalHealthPlatform get platform;
  Future<HealthStoreAvailability> availability();
  Future<HealthReadConsent> requestReadAccess();
  Future<LocalHealthRead> read({
    required HealthReadWindow window,
    required String localSessionScope,
  });
}
