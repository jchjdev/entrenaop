import 'dart:convert';

import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesWorkoutTimerStore implements WorkoutTimerStore {
  const SharedPreferencesWorkoutTimerStore(this._preferences);

  static const _prefix = 'workout_timer_v1:';

  final SharedPreferences _preferences;

  @override
  Future<WorkoutTimerSnapshot?> read(String timerId) async {
    final encoded = _preferences.getString('$_prefix$timerId');
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      return WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.values.byName(json['phase'] as String),
        targetSeconds: json['target_seconds'] as int,
        preparationSeconds: json['preparation_seconds'] as int,
        phaseStartedAt: DateTime.parse(json['phase_started_at'] as String),
        elapsedBeforeRun: Duration(
          milliseconds: json['elapsed_before_run_ms'] as int,
        ),
        restCanBeSkipped: json['rest_can_be_skipped'] as bool? ?? true,
      );
    } on Object {
      // Un dato local antiguo o corrupto nunca debe impedir abrir la sesión.
      await clear(timerId);
      return null;
    }
  }

  @override
  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot) async {
    await _preferences.setString(
      '$_prefix$timerId',
      jsonEncode({
        'phase': snapshot.phase.name,
        'target_seconds': snapshot.targetSeconds,
        'preparation_seconds': snapshot.preparationSeconds,
        'phase_started_at': snapshot.phaseStartedAt.toUtc().toIso8601String(),
        'elapsed_before_run_ms': snapshot.elapsedBeforeRun.inMilliseconds,
        'rest_can_be_skipped': snapshot.restCanBeSkipped,
      }),
    );
  }

  @override
  Future<void> clear(String timerId) => _preferences.remove('$_prefix$timerId');
}
