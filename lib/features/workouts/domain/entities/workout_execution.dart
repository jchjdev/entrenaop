import 'package:equatable/equatable.dart';

enum WorkoutExecutionStatus { inProgress, completed, abandoned }

enum WorkoutSetStatus { pending, completed, skipped }

class WorkoutExecution extends Equatable {
  const WorkoutExecution({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.templateVersion,
    required this.status,
    required this.startedAt,
    required this.sets,
    this.completedAt,
    this.finalRpe,
    this.notes,
  });

  final String id;
  final String templateId;
  final String templateName;
  final int templateVersion;
  final WorkoutExecutionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? finalRpe;
  final String? notes;
  final List<WorkoutExecutionSet> sets;

  WorkoutExecutionSet? get currentSet {
    for (final set in sets) {
      if (set.status == WorkoutSetStatus.pending) return set;
    }
    return null;
  }

  int get completedSetCount =>
      sets.where((set) => set.status == WorkoutSetStatus.completed).length;

  int get skippedSetCount =>
      sets.where((set) => set.status == WorkoutSetStatus.skipped).length;

  /// Una serie queda resuelta tanto si se completa como si se omite.
  /// Usamos este dato para el progreso sin confundir ambos resultados.
  int get resolvedSetCount => completedSetCount + skippedSetCount;

  @override
  List<Object?> get props => [
    id,
    templateId,
    templateName,
    templateVersion,
    status,
    startedAt,
    completedAt,
    finalRpe,
    notes,
    sets,
  ];
}

/// Resultado real introducido por el deportista al terminar una serie.
///
/// Se mantiene separado de [WorkoutExecutionSet] para no reutilizar por error
/// la prescripcion como si fuera el resultado ejecutado.
class WorkoutSetResultInput extends Equatable {
  const WorkoutSetResultInput({
    required this.resultId,
    this.actualReps,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualLoadKg,
    this.actualRpe,
    this.actualRir,
  });

  final String resultId;
  final int? actualReps;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;

  @override
  List<Object?> get props => [
    resultId,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
  ];
}

class WorkoutExecutionSet extends Equatable {
  const WorkoutExecutionSet({
    required this.id,
    required this.blockOrder,
    required this.blockName,
    required this.itemOrder,
    required this.exerciseId,
    required this.exerciseName,
    required this.setOrder,
    required this.restAfterSeconds,
    required this.status,
    this.targetReps,
    this.targetDurationSeconds,
    this.targetDistanceMeters,
    this.targetLoadKg,
    this.targetRpe,
    this.targetRir,
    this.actualReps,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualLoadKg,
    this.actualRpe,
    this.actualRir,
  });

  final String id;
  final int blockOrder;
  final String blockName;
  final int itemOrder;
  final String exerciseId;
  final String exerciseName;
  final int setOrder;
  final int? targetReps;
  final int? targetDurationSeconds;
  final double? targetDistanceMeters;
  final double? targetLoadKg;
  final double? targetRpe;
  final double? targetRir;
  final int restAfterSeconds;
  final WorkoutSetStatus status;
  final int? actualReps;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;

  @override
  List<Object?> get props => [
    id,
    blockOrder,
    blockName,
    itemOrder,
    exerciseId,
    exerciseName,
    setOrder,
    targetReps,
    targetDurationSeconds,
    targetDistanceMeters,
    targetLoadKg,
    targetRpe,
    targetRir,
    restAfterSeconds,
    status,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
  ];
}
