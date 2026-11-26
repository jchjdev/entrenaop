import 'dart:math' as math;

import '../entities/workout_execution.dart';
import '../entities/workout_template.dart';

abstract interface class PhoneRunLocationSource {
  Stream<PhoneRunLocationEvent> get locations;
  Future<void> start(String token);
  Future<void> stop(String token);
}

class PhoneRunLocationEvent {
  const PhoneRunLocationEvent(this.token, {this.fix, this.error});

  final String token;
  final PhoneRunFix? fix;
  final String? error;
}

class PhoneRunLocationFailure implements Exception {
  const PhoneRunLocationFailure(this.code);

  final String code;
}

abstract interface class PhoneRunCheckpoints {
  Future<PhoneRunCheckpoint?> read(String executionId);
  Future<void> write(String executionId, PhoneRunCheckpoint value);
  Future<void> clear(String executionId);
}

enum PhoneRunVoice { off, series, splits }

class PhoneRunLap {
  const PhoneRunLap(this.stepId, this.totals);

  final String stepId;
  final PhoneRunTotals totals;
}

abstract interface class PhoneRunFeedback {
  Future<void> publish(
    String token, {
    required String phase,
    required String progress,
    required String pace,
    required String distance,
    required int seconds,
  });
  Future<void> end(String token);
  Future<void> speak(String text);
  Future<void> silence();
}

class PhoneRunCheckpoint {
  const PhoneRunCheckpoint(
    this.totals, {
    required this.recording,
    this.stepId,
    this.laps = const [],
    this.trackMode = false,
    this.voice = PhoneRunVoice.off,
    this.paceAlerts = false,
  });

  final PhoneRunTotals totals;
  final bool recording;
  final String? stepId;
  final List<PhoneRunLap> laps;
  final bool trackMode, paceAlerts;
  final PhoneRunVoice voice;
}

/// El rodaje fácil publicado es un único tramo de carrera por tiempo.
/// Comprobar su forma evita depender del nombre traducido de la pauta.
bool isContinuousPhoneRun(WorkoutTemplate workout) {
  final block = workout.blocks.where((b) => !b.attachedWarmup).singleOrNull;
  if (block == null ||
      block.format != WorkoutBlockFormat.running ||
      block.rounds != 1 ||
      block.restAfterSeconds != 0 ||
      block.timeCapSeconds != null) {
    return false;
  }
  final item = block.items.singleOrNull;
  final set = item?.sets.singleOrNull;
  return item?.exerciseId == runningExerciseId &&
      set != null &&
      set.targetReps == null &&
      set.performancePrescription == null &&
      set.restAfterSeconds == 0 &&
      set.recoveryType == null &&
      set.recoveryDurationSeconds == null &&
      set.recoveryDistanceMeters == null &&
      _timedRun(
        set.targetDurationSeconds,
        set.targetDistanceMeters,
        set.runningStep,
      );
}

WorkoutExecutionSet? continuousPhoneRunSet(WorkoutExecution execution) {
  final set = execution.sets
      .where(
        (s) =>
            s.blockFormat != WorkoutBlockFormat.warmUp ||
            s.exerciseId == runningExerciseId,
      )
      .singleOrNull;
  if (execution.status != WorkoutExecutionStatus.inProgress ||
      set == null ||
      execution.currentSet?.id != set.id ||
      set.status != WorkoutSetStatus.pending ||
      set.blockFormat != WorkoutBlockFormat.running ||
      set.exerciseId != runningExerciseId ||
      set.performancePrescription != null ||
      set.targetReps != null ||
      set.restAfterSeconds != 0 ||
      set.recoveryType != null ||
      set.recoveryDurationSeconds != null ||
      set.recoveryDistanceMeters != null ||
      !_timedRun(
        set.targetDurationSeconds,
        set.targetDistanceMeters,
        set.runningStep,
      )) {
    return null;
  }
  return set;
}

bool _timedRun(int? seconds, double? meters, RunningStepMetadata? step) =>
    (seconds ?? 0) > 0 &&
    meters == null &&
    (step == null ||
        (step.kind == RunningStepKind.run &&
            step.completion == RunningStepCompletion.time));

class PhoneRunFix {
  const PhoneRunFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.at,
  });

  final double latitude, longitude, accuracyMeters;
  final DateTime at;

  double distanceTo(PhoneRunFix other) {
    const radiansPerDegree = math.pi / 180;
    final deltaLat = (other.latitude - latitude) * radiansPerDegree;
    final deltaLon = (other.longitude - longitude) * radiansPerDegree;
    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);
    final a =
        sinLat * sinLat +
        math.cos(latitude * radiansPerDegree) *
            math.cos(other.latitude * radiansPerDegree) *
            sinLon *
            sinLon;
    return 2 * 6371000 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }
}

class PhoneRunTotals {
  const PhoneRunTotals({
    this.elapsedMilliseconds = 0,
    this.distanceMeters = 0,
    this.distanceReliable = true,
  });

  final int elapsedMilliseconds;
  final double distanceMeters;
  final bool distanceReliable;

  int get seconds => (elapsedMilliseconds / 1000).round();
  int? get paceSecondsPerKm =>
      distanceReliable && distanceMeters >= 50 && seconds > 0
      ? (elapsedMilliseconds / distanceMeters).round()
      : null;
}

class PhoneRunTrack {
  PhoneRunTrack([this._previous = const PhoneRunTotals()]);

  static const maxSignalGap = Duration(seconds: 12);
  PhoneRunTotals _previous;
  PhoneRunFix? _anchor, _latest;
  DateTime? _legStartedAt;
  double _legMeters = 0;
  bool _missingDistance = false;
  final _samples = <(DateTime, double)>[];

  bool get hasFix => _legStartedAt != null;

  bool signalLostAt(DateTime now) {
    final latest = _latest;
    return latest != null && now.difference(latest.at) > maxSignalGap;
  }

  void add(PhoneRunFix fix, DateTime now) {
    if (!fix.latitude.isFinite ||
        fix.latitude.abs() > 90 ||
        !fix.longitude.isFinite ||
        fix.longitude.abs() > 180 ||
        !fix.accuracyMeters.isFinite ||
        fix.accuracyMeters <= 0 ||
        fix.accuracyMeters > 15 ||
        fix.at.isAfter(now.add(const Duration(seconds: 1))) ||
        now.difference(fix.at) > maxSignalGap) {
      return;
    }
    final latest = _latest;
    if (latest != null && !fix.at.isAfter(latest.at)) return;
    // Un hueco de señal nunca se rellena con una recta entre sus extremos.
    if (latest == null || signalLostAt(fix.at)) {
      _missingDistance |=
          latest != null ||
          (_legStartedAt != null &&
              fix.at.difference(_legStartedAt!) > maxSignalGap);
      _legStartedAt ??= fix.at;
      _anchor = _latest = fix;
      _samples.clear();
      _addSample(fix.at);
      return;
    }
    final anchor = _anchor!;
    final meters = anchor.distanceTo(fix);
    final seconds = fix.at.difference(anchor.at).inMilliseconds / 1000;
    if (meters >
        12 * seconds + math.max(anchor.accuracyMeters, fix.accuracyMeters)) {
      return;
    }
    _latest = fix;
    // Mantener el punto de referencia evita sumar pequeñas oscilaciones del GPS.
    final noise = ((anchor.accuracyMeters + fix.accuracyMeters) / 4).clamp(
      3,
      8,
    );
    if (meters >= noise) {
      _legMeters += meters;
      _anchor = fix;
    }
    _addSample(fix.at);
  }

  void _addSample(DateTime at) {
    _samples.removeWhere((sample) => at.difference(sample.$1).inSeconds > 20);
    _samples.add((at, _legMeters));
  }

  int? recentPaceAt(DateTime now) {
    if (_samples.length < 2 || signalLostAt(now)) return null;
    final first = _samples.first, last = _samples.last;
    final meters = last.$2 - first.$2;
    final elapsed = last.$1.difference(first.$1);
    if (meters < 12 || elapsed.inSeconds < 6) return null;
    return (elapsed.inMilliseconds / meters).round();
  }

  PhoneRunTrack nextStep(DateTime now) {
    final next = PhoneRunTrack().._legStartedAt = now;
    if (!signalLostAt(now)) {
      next._anchor = next._latest = _latest;
    }
    return next;
  }

  PhoneRunTotals totalsAt(DateTime now) {
    final start = _legStartedAt;
    return PhoneRunTotals(
      elapsedMilliseconds:
          _previous.elapsedMilliseconds +
          (start == null
              ? 0
              : math.max(0, now.difference(start).inMilliseconds)),
      distanceMeters: _previous.distanceMeters + _legMeters,
      distanceReliable:
          _previous.distanceReliable && !_missingDistance && !signalLostAt(now),
    );
  }

  PhoneRunTotals pause(DateTime now) {
    _previous = totalsAt(now);
    _legStartedAt = null;
    _anchor = _latest = null;
    _legMeters = 0;
    _missingDistance = false;
    _samples.clear();
    return _previous;
  }
}
