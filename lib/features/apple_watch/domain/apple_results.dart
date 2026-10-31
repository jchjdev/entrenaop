import 'package:workout_core/device_activity_summary.dart';

import 'apple_training.dart';

class AppleResultCatalog {
  const AppleResultCatalog(this.enabled, this.plans, this.results);
  final bool enabled;
  final List<ApplePlan> plans;
  final List<DeviceActivitySummary> results;
}

abstract interface class AppleResultsRepository {
  bool get isCurrent;
  Future<AppleResultCatalog> load();
  Future<void> enable(bool enabled);
  Future<void> ingest(List<AppleResultObservation> observations);
  Future<void> classify(String id, bool isTest);
}

abstract interface class AppleResultsReader {
  bool get supported;
  Future<void> authorize();
  Future<List<AppleResultObservation>> read(List<ApplePlan> plans);
}

class AppleResultObservation {
  const AppleResultObservation({
    required this.workoutId,
    required this.planId,
    required this.revision,
    required this.matchesPrescription,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
    this.meters,
    this.averageHeartRate,
    this.maxHeartRate,
    this.intervals = const [],
    this.markers = const [],
    this.effortScore,
    this.offsetMinutes,
  });
  final String workoutId, planId, revision;
  final bool matchesPrescription;
  final DateTime startedAt, endedAt;
  final double seconds;
  final double? meters, averageHeartRate, maxHeartRate;
  final List<AppleResultInterval> intervals;
  final List<AppleResultMarker> markers;
  final double? effortScore;
  final int? offsetMinutes;
}

class AppleResultInterval {
  const AppleResultInterval(
    this.id,
    this.startedAt,
    this.endedAt,
    this.seconds, {
    this.meters,
    this.averageHeartRate,
    this.maxHeartRate,
  });
  final String id;
  final DateTime startedAt, endedAt;
  final double seconds;
  final double? meters, averageHeartRate, maxHeartRate;
}

class AppleResultMarker {
  const AppleResultMarker(this.kind, this.startedAt, this.endedAt);
  final String kind;
  final DateTime startedAt, endedAt;
}

/// Repetir una lectura es seguro: el servidor identifica el objeto HealthKit.
/// La sesión autenticada se comprueba también después de cada operación nativa.
class SyncAppleResults {
  SyncAppleResults(this.repository, this.reader);
  final AppleResultsRepository repository;
  final AppleResultsReader reader;
  bool _busy = false;
  bool _active = true;

  void dispose() => _active = false;
  void _check() {
    if (!_active || !repository.isCurrent) {
      throw const AppleTrainingFailure('account_changed');
    }
  }

  Future<AppleResultCatalog?> call() async {
    _check();
    if (_busy) return null;
    _busy = true;
    try {
      final catalog = await repository.load();
      _check();
      if (!catalog.enabled || !reader.supported || catalog.plans.isEmpty) {
        return catalog;
      }
      final observations = await reader.read(catalog.plans);
      _check();
      for (var i = 0; i < observations.length; i += 20) {
        await repository.ingest(
          observations.sublist(
            i,
            i + 20 < observations.length ? i + 20 : observations.length,
          ),
        );
        _check();
      }
      final result = await repository.load();
      _check();
      return result;
    } finally {
      _busy = false;
    }
  }
}
