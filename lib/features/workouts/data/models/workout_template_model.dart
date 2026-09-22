import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

class WorkoutTemplateModel {
  const WorkoutTemplateModel._();

  static WorkoutTemplate fromJson(Map<String, dynamic> json) {
    final blocks =
        _maps(json['workout_blocks'])
            .map(_blockFromJson)
            .toList(growable: false)
          ..sort((first, second) => first.order.compareTo(second.order));

    return WorkoutTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      version: json['version'] as int,
      blocks: blocks.map((entry) => entry.value).toList(growable: false),
    );
  }

  static ({int order, WorkoutBlock value}) _blockFromJson(
    Map<String, dynamic> json,
  ) {
    final items =
        _maps(json['workout_items']).map(_itemFromJson).toList(growable: false)
          ..sort((first, second) => first.order.compareTo(second.order));

    return (
      order: json['order_index'] as int,
      value: WorkoutBlock(
        id: json['id'] as String,
        name: json['name'] as String,
        format: _formatFromJson(json['format'] as String),
        rounds: json['rounds'] as int,
        timeCapSeconds: json['time_cap_seconds'] as int?,
        restAfterSeconds: json['rest_after_seconds'] as int,
        items: items.map((entry) => entry.value).toList(growable: false),
      ),
    );
  }

  static ({int order, WorkoutItem value}) _itemFromJson(
    Map<String, dynamic> json,
  ) {
    final exercise = json['exercises'] as Map<String, dynamic>;
    final sets =
        _maps(json['workout_sets']).map(_setFromJson).toList(growable: false)
          ..sort((first, second) => first.order.compareTo(second.order));

    return (
      order: json['order_index'] as int,
      value: WorkoutItem(
        id: json['id'] as String,
        exerciseId: exercise['id'] as String,
        exerciseName: exercise['name'] as String,
        exerciseDescription: exercise['description'] as String?,
        notes: json['notes'] as String?,
        sets: sets.map((entry) => entry.value).toList(growable: false),
      ),
    );
  }

  static ({int order, WorkoutSet value}) _setFromJson(
    Map<String, dynamic> json,
  ) {
    final order = json['order_index'] as int;
    return (
      order: order,
      value: WorkoutSet(
        id: json['id'] as String,
        order: order,
        targetReps: json['target_reps'] as int?,
        targetDurationSeconds: json['target_duration_seconds'] as int?,
        targetDistanceMeters: _doubleOrNull(json['target_distance_meters']),
        targetLoadKg: _doubleOrNull(json['target_load_kg']),
        targetRpe: _doubleOrNull(json['target_rpe']),
        targetRir: _doubleOrNull(json['target_rir']),
        targetPaceMinSecondsPerKm:
            json['target_pace_min_seconds_per_km'] as int?,
        targetPaceMaxSecondsPerKm:
            json['target_pace_max_seconds_per_km'] as int?,
        recoveryType: _recoveryType(json['recovery_type']),
        recoveryDurationSeconds: json['recovery_duration_seconds'] as int?,
        recoveryDistanceMeters: _doubleOrNull(json['recovery_distance_meters']),
        restAfterSeconds: json['rest_after_seconds'] as int,
      ),
    );
  }

  static List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List? ?? const []).cast<Map<String, dynamic>>().toList(
        growable: false,
      );

  static double? _doubleOrNull(Object? value) =>
      value == null ? null : (value as num).toDouble();

  static WorkoutBlockFormat _formatFromJson(String value) => switch (value) {
    'straight_sets' => WorkoutBlockFormat.straightSets,
    'circuit' => WorkoutBlockFormat.circuit,
    'superset' => WorkoutBlockFormat.superset,
    'intervals' => WorkoutBlockFormat.intervals,
    'emom' => WorkoutBlockFormat.emom,
    'amrap' => WorkoutBlockFormat.amrap,
    'tabata' => WorkoutBlockFormat.tabata,
    'running' => WorkoutBlockFormat.running,
    'warm_up' => WorkoutBlockFormat.warmUp,
    'cool_down' => WorkoutBlockFormat.coolDown,
    _ => throw FormatException('Formato de bloque desconocido: $value'),
  };

  static RunningRecoveryType? _recoveryType(Object? value) => switch (value) {
    null => null,
    'passive' => RunningRecoveryType.passive,
    'walking' => RunningRecoveryType.walking,
    'jogging' => RunningRecoveryType.jogging,
    _ => throw FormatException('Recuperación de carrera desconocida: $value'),
  };
}

class WorkoutTemplateSummaryModel {
  const WorkoutTemplateSummaryModel._();

  static WorkoutTemplateSummary fromJson(Map<String, dynamic> json) =>
      WorkoutTemplateSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
        origin: switch (json['origin'] as String) {
          'system' => WorkoutTemplateOrigin.system,
          'user' => WorkoutTemplateOrigin.user,
          'coach' => WorkoutTemplateOrigin.coach,
          'algorithm' => WorkoutTemplateOrigin.algorithm,
          final value => throw FormatException(
            'Origen de sesión desconocido: $value',
          ),
        },
        version: json['version'] as int,
        isRunning: ((json['workout_blocks'] as List?) ?? const []).any(
          (block) => (block as Map)['format'] == 'running',
        ),
      );
}
