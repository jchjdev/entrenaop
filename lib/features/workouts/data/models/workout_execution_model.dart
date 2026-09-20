import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';

class WorkoutExecutionModel {
  const WorkoutExecutionModel._();

  static WorkoutExecution fromJson(Map<String, dynamic> json) {
    final sets =
        (json['workout_execution_sets'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(_setFromJson)
            .toList(growable: false)
          ..sort(_compareSets);

    return WorkoutExecution(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      templateName: json['template_name'] as String,
      templateVersion: json['template_version'] as int,
      status: _executionStatus(json['status'] as String),
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: _dateOrNull(json['completed_at']),
      finalRpe: json['final_rpe'] as int?,
      notes: json['notes'] as String?,
      sets: sets,
    );
  }

  static WorkoutExecutionSet _setFromJson(Map<String, dynamic> json) {
    return WorkoutExecutionSet(
      id: json['id'] as String,
      blockOrder: json['block_order'] as int,
      blockName: json['block_name'] as String,
      itemOrder: json['item_order'] as int,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      setOrder: json['set_order'] as int,
      targetReps: json['target_reps'] as int?,
      targetDurationSeconds: json['target_duration_seconds'] as int?,
      targetDistanceMeters: _doubleOrNull(json['target_distance_meters']),
      targetLoadKg: _doubleOrNull(json['target_load_kg']),
      targetRpe: _doubleOrNull(json['target_rpe']),
      targetRir: _doubleOrNull(json['target_rir']),
      restAfterSeconds: json['rest_after_seconds'] as int,
      status: _setStatus(json['status'] as String),
      actualReps: json['actual_reps'] as int?,
      actualDurationSeconds: json['actual_duration_seconds'] as int?,
      actualDistanceMeters: _doubleOrNull(json['actual_distance_meters']),
      actualLoadKg: _doubleOrNull(json['actual_load_kg']),
      actualRpe: _doubleOrNull(json['actual_rpe']),
      actualRir: _doubleOrNull(json['actual_rir']),
    );
  }

  static int _compareSets(
    WorkoutExecutionSet first,
    WorkoutExecutionSet second,
  ) {
    final block = first.blockOrder.compareTo(second.blockOrder);
    if (block != 0) return block;
    final item = first.itemOrder.compareTo(second.itemOrder);
    if (item != 0) return item;
    return first.setOrder.compareTo(second.setOrder);
  }

  static WorkoutExecutionStatus _executionStatus(String value) =>
      switch (value) {
        'in_progress' => WorkoutExecutionStatus.inProgress,
        'completed' => WorkoutExecutionStatus.completed,
        'abandoned' => WorkoutExecutionStatus.abandoned,
        _ => throw FormatException('Estado de ejecución desconocido: $value'),
      };

  static WorkoutSetStatus _setStatus(String value) => switch (value) {
    'pending' => WorkoutSetStatus.pending,
    'completed' => WorkoutSetStatus.completed,
    'skipped' => WorkoutSetStatus.skipped,
    _ => throw FormatException('Estado de serie desconocido: $value'),
  };

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static double? _doubleOrNull(Object? value) =>
      value == null ? null : (value as num).toDouble();
}
