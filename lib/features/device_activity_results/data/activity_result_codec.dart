import '../domain/activity_result.dart';

ActivityResultReview decodeActivityReview(Map<String, dynamic> data) {
  final activity = data['activity'] as Map;
  final offset = activity['offsetSeconds'] as int?;
  if (offset != null && offset % 60 != 0) {
    throw const FormatException('Reloj local inválido');
  }
  return ActivityResultReview(
    activityId: data['activity_id'] as String,
    activityRevision: data['activity_revision'] as String,
    scheduledId: data['scheduled_id'] as String,
    sourceRevision: data['source_revision'] as String,
    name: activity['name'] as String,
    startedAt: DateTime.parse(activity['startedAt'] as String),
    seconds: (activity['timerSeconds'] as num).toDouble(),
    meters: (activity['distanceMeters'] as num?)?.toDouble(),
    sport: activity['sport'] as String? ?? 'running',
    offsetMinutes: offset == null ? null : offset ~/ 60,
    averageHeartRate: (activity['averageHeartRate'] as num?)?.round(),
    recordedRpe: data['recorded_rpe'] as int?,
    isTest: data['is_test'] == true,
    requiresMeasuredStep: data['requires_measured_step'] == true,
    blockedReason: data['blocked_reason'] as String?,
    laps: [
      for (final lap
          in (activity['sport'] == 'strength'
                  ? activity['sets']
                  : activity['laps'])
              as List)
        RecordedLap(
          lap['index'] as int,
          (lap[activity['sport'] == 'strength' ? 'seconds' : 'timerSeconds']
                  as num)
              .toDouble(),
          (lap['distanceMeters'] as num?)?.toDouble(),
          lap[activity['sport'] == 'strength' ? 'kind' : 'intensity']
              as String?,
          strength: activity['sport'] == 'strength',
          repetitions: lap['repetitions'] as int?,
          loadKg: (lap['loadKg'] as num?)?.toDouble(),
        ),
    ],
    rows: [
      for (final row in data['rows'] as List)
        LapAssignment(
          block: row['block_order'] as int,
          item: row['item_order'] as int,
          set: row['set_order'] as int,
          label: row['label'] as String,
          requiresRecovery: row['requires_recovery'] as bool,
          strength: activity['sport'] == 'strength',
          requiresReps: row['measure'] == 'reps',
          requiresDistance: row['requires_distance'] == true,
          requiresRecoveryDistance: row['requires_recovery_distance'] == true,
          laps: List<int>.unmodifiable(row['lap_indices'] as List),
          recoveryLaps: List<int>.unmodifiable(
            row['recovery_lap_indices'] as List,
          ),
        ),
    ],
  );
}
