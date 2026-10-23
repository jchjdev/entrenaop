class ActivityResultException implements Exception {
  const ActivityResultException(this.code);
  final String code;
}

class ReceivedRun {
  const ReceivedRun(
    this.id,
    this.revision,
    this.name,
    this.startedAt,
    this.seconds,
    this.meters,
    this.executionId, {
    this.sport = 'running',
  });
  final String id, revision, name;
  final DateTime startedAt;
  final double seconds, meters;
  final String? executionId;
  final String sport;
}

class RunAppointment {
  const RunAppointment(this.id, this.name, this.date, {this.sport = 'running'});
  final String id, name, date;
  final String sport;
}

class ActivityResultCatalog {
  const ActivityResultCatalog(this.runs, this.appointments, this.problems);
  final List<ReceivedRun> runs;
  final List<RunAppointment> appointments;
  final List<String> problems;
}

class RecordedLap {
  const RecordedLap(
    this.index,
    this.seconds,
    this.meters,
    this.kind, {
    this.strength = false,
    this.repetitions,
    this.loadKg,
  });
  final int index;
  final double seconds, meters;
  final String? kind;
  final bool strength;
  final int? repetitions;
  final double? loadKg;
}

class LapAssignment {
  const LapAssignment({
    required this.block,
    required this.item,
    required this.set,
    required this.label,
    required this.requiresRecovery,
    this.laps = const [],
    this.recoveryLaps = const [],
    this.skipped = false,
    this.strength = false,
    this.requiresReps = false,
  });
  final int block, item, set;
  final String label;
  final bool requiresRecovery, skipped;
  final bool strength, requiresReps;
  final List<int> laps, recoveryLaps;
  LapAssignment select({
    List<int>? laps,
    List<int>? recoveryLaps,
    bool? skipped,
  }) => LapAssignment(
    block: block,
    item: item,
    set: set,
    label: label,
    requiresRecovery: requiresRecovery,
    laps: List.unmodifiable(laps ?? this.laps),
    recoveryLaps: List.unmodifiable(recoveryLaps ?? this.recoveryLaps),
    skipped: skipped ?? this.skipped,
    strength: strength,
    requiresReps: requiresReps,
  );
}

class ActivityResultReview {
  const ActivityResultReview({
    required this.activityId,
    required this.activityRevision,
    required this.scheduledId,
    required this.sourceRevision,
    required this.name,
    required this.startedAt,
    required this.seconds,
    required this.meters,
    required this.offsetMinutes,
    required this.averageHeartRate,
    required this.laps,
    required this.rows,
    this.sport = 'running',
  });
  final String activityId, activityRevision, scheduledId, sourceRevision, name;
  final DateTime startedAt;
  final double seconds, meters;
  final int? offsetMinutes, averageHeartRate;
  final List<RecordedLap> laps;
  final List<LapAssignment> rows;
  final String sport;
}

class ConfirmActivityResult {
  ConfirmActivityResult({
    required this.operationId,
    required this.review,
    required this.rpe,
    required this.offsetMinutes,
    required List<LapAssignment> rows,
  }) : rows = List.unmodifiable(rows);
  final String operationId;
  final ActivityResultReview review;
  final int rpe, offsetMinutes;
  final List<LapAssignment> rows;
}

/// La misma vuelta no puede acreditar dos series o una serie y su recuperación.
bool validLapAssignments(List<LapAssignment> rows, List<RecordedLap> laps) {
  if (rows.isEmpty) return false;
  final used = <int>{};
  bool validGroup(List<int> indices) {
    if (indices.isEmpty) return false;
    for (var i = 0; i < indices.length; i++) {
      final index = indices[i];
      if (index < 0 ||
          index >= laps.length ||
          !used.add(index) ||
          (i > 0 && index != indices[i - 1] + 1)) {
        return false;
      }
    }
    return true;
  }

  for (final row in rows) {
    if (row.skipped) continue;
    if (!validGroup(row.laps)) {
      return false;
    }
    if (row.strength &&
        (row.laps.length != 1 ||
            !laps[row.laps.single].strength ||
            laps[row.laps.single].kind != 'active' ||
            row.requiresReps && laps[row.laps.single].repetitions == null)) {
      return false;
    }
    if (row.requiresRecovery) {
      if (!validGroup(row.recoveryLaps) ||
          row.recoveryLaps.first <= row.laps.last) {
        return false;
      }
    } else if (row.recoveryLaps.isNotEmpty) {
      return false;
    }
  }
  return true;
}

abstract interface class ActivityResultRepository {
  Future<ActivityResultCatalog> load();
  Future<ActivityResultReview> preview(String activityId, String scheduledId);
  Future<String> confirm(ConfirmActivityResult request);
}
