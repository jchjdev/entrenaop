import 'package:equatable/equatable.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';

enum WorkoutExecutionStatus { inProgress, completed, abandoned }

enum WorkoutSetStatus { pending, completed, skipped }

enum WorkoutAbandonmentReason { lackOfTime, tooDifficult, discomfort, other }

enum WorkoutResultSource { manual, device }

class WorkoutExecution extends Equatable {
  const WorkoutExecution({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.templateVersion,
    required this.status,
    required this.startedAt,
    required this.sets,
    this.amrapResults = const [],
    this.completedAt,
    this.finalRpe,
    this.notes,
    this.abandonmentReason,
    this.averageHeartRateBpm,
    this.maxHeartRateBpm,
    this.resultSource,
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
  final WorkoutAbandonmentReason? abandonmentReason;
  final int? averageHeartRateBpm;
  final int? maxHeartRateBpm;
  final WorkoutResultSource? resultSource;
  final List<WorkoutExecutionSet> sets;
  final List<WorkoutAmrapResult> amrapResults;

  WorkoutAmrapResult? amrapResultFor(int blockOrder) {
    for (final result in amrapResults) {
      if (result.blockOrder == blockOrder) return result;
    }
    return null;
  }

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

  WorkoutExecution copyWith({
    WorkoutExecutionStatus? status,
    DateTime? completedAt,
    int? finalRpe,
    String? notes,
    WorkoutAbandonmentReason? abandonmentReason,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
    WorkoutResultSource? resultSource,
    List<WorkoutExecutionSet>? sets,
    List<WorkoutAmrapResult>? amrapResults,
  }) => WorkoutExecution(
    id: id,
    templateId: templateId,
    templateName: templateName,
    templateVersion: templateVersion,
    status: status ?? this.status,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    finalRpe: finalRpe ?? this.finalRpe,
    notes: notes ?? this.notes,
    abandonmentReason: abandonmentReason ?? this.abandonmentReason,
    averageHeartRateBpm: averageHeartRateBpm ?? this.averageHeartRateBpm,
    maxHeartRateBpm: maxHeartRateBpm ?? this.maxHeartRateBpm,
    resultSource: resultSource ?? this.resultSource,
    sets: sets ?? this.sets,
    amrapResults: amrapResults ?? this.amrapResults,
  );

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
    abandonmentReason,
    averageHeartRateBpm,
    maxHeartRateBpm,
    resultSource,
    sets,
    amrapResults,
  ];
}

class WorkoutAmrapResult extends Equatable {
  const WorkoutAmrapResult({
    required this.blockOrder,
    required this.completedRounds,
    required this.completedAt,
    this.partialItemOrder,
    this.partialReps = 0,
  });

  final int blockOrder;
  final int completedRounds;
  final int? partialItemOrder;
  final int partialReps;
  final DateTime completedAt;

  @override
  List<Object?> get props => [
    blockOrder,
    completedRounds,
    partialItemOrder,
    partialReps,
    completedAt,
  ];
}

class WorkoutAmrapResultInput extends Equatable {
  const WorkoutAmrapResultInput({
    required this.executionId,
    required this.blockOrder,
    required this.completedRounds,
    this.partialItemOrder,
    this.partialReps = 0,
  });

  final String executionId;
  final int blockOrder;
  final int completedRounds;
  final int? partialItemOrder;
  final int partialReps;

  @override
  List<Object?> get props => [
    executionId,
    blockOrder,
    completedRounds,
    partialItemOrder,
    partialReps,
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
    this.actualRecoveryDurationSeconds,
    this.actualRecoveryDistanceMeters,
    this.resultSource = WorkoutResultSource.manual,
  });

  final String resultId;
  final int? actualReps;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;
  final int? actualRecoveryDurationSeconds;
  final double? actualRecoveryDistanceMeters;
  final WorkoutResultSource resultSource;

  @override
  List<Object?> get props => [
    resultId,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
    actualRecoveryDurationSeconds,
    actualRecoveryDistanceMeters,
    resultSource,
  ];
}

/// Corrección explícita de una serie ya guardada.
///
/// El motivo acompaña al cambio para que el servidor pueda conservar una
/// auditoría y limitar las correcciones sin confiar en la interfaz.
class WorkoutSetCorrectionInput extends Equatable {
  const WorkoutSetCorrectionInput({
    required this.resultId,
    required this.reason,
    this.actualReps,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualLoadKg,
    this.actualRpe,
    this.actualRir,
    this.actualRecoveryDurationSeconds,
    this.actualRecoveryDistanceMeters,
    this.resultSource = WorkoutResultSource.manual,
  });

  final String resultId;
  final String reason;
  final int? actualReps;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;
  final int? actualRecoveryDurationSeconds;
  final double? actualRecoveryDistanceMeters;
  final WorkoutResultSource resultSource;

  @override
  List<Object?> get props => [
    resultId,
    reason,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
    actualRecoveryDurationSeconds,
    actualRecoveryDistanceMeters,
    resultSource,
  ];
}

class WorkoutExecutionSet extends Equatable {
  const WorkoutExecutionSet({
    required this.id,
    required this.blockOrder,
    required this.blockName,
    this.blockFormat = WorkoutBlockFormat.straightSets,
    this.blockTimeCapSeconds,
    required this.itemOrder,
    required this.exerciseId,
    required this.exerciseName,
    required this.setOrder,
    required this.restAfterSeconds,
    required this.status,
    this.targetReps,
    this.exerciseDescription,
    this.exerciseVideoUrl,
    this.targetDurationSeconds,
    this.targetDistanceMeters,
    this.targetLoadKg,
    this.targetRpe,
    this.targetRir,
    this.targetPaceMinSecondsPerKm,
    this.targetPaceMaxSecondsPerKm,
    this.recoveryType,
    this.recoveryDurationSeconds,
    this.recoveryDistanceMeters,
    this.actualReps,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualLoadKg,
    this.actualRpe,
    this.actualRir,
    this.actualRecoveryDurationSeconds,
    this.actualRecoveryDistanceMeters,
    this.resultSource,
    this.completedAt,
  });

  final String id;
  final int blockOrder;
  final String blockName;
  final WorkoutBlockFormat blockFormat;
  final int? blockTimeCapSeconds;
  final int itemOrder;
  final String exerciseId;
  final String exerciseName;
  final String? exerciseDescription;
  final String? exerciseVideoUrl;
  final int setOrder;
  final int? targetReps;
  final int? targetDurationSeconds;
  final double? targetDistanceMeters;
  final double? targetLoadKg;
  final double? targetRpe;
  final double? targetRir;
  final int? targetPaceMinSecondsPerKm;
  final int? targetPaceMaxSecondsPerKm;
  final RunningRecoveryType? recoveryType;
  final int? recoveryDurationSeconds;
  final double? recoveryDistanceMeters;
  final int restAfterSeconds;
  final WorkoutSetStatus status;
  final int? actualReps;
  final int? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;
  final int? actualRecoveryDurationSeconds;
  final double? actualRecoveryDistanceMeters;
  final WorkoutResultSource? resultSource;
  final DateTime? completedAt;

  bool get isGrouped =>
      blockFormat == WorkoutBlockFormat.superset ||
      blockFormat == WorkoutBlockFormat.circuit ||
      blockFormat == WorkoutBlockFormat.intervals ||
      blockFormat == WorkoutBlockFormat.tabata ||
      blockFormat == WorkoutBlockFormat.emom ||
      blockFormat == WorkoutBlockFormat.amrap;

  int get roundNumber => setOrder + 1;

  bool canBeCorrectedAt(DateTime now) {
    final savedAt = completedAt;
    return status == WorkoutSetStatus.completed &&
        savedAt != null &&
        !now.isAfter(savedAt.add(const Duration(hours: 24)));
  }

  WorkoutExecutionSet copyWith({
    WorkoutSetStatus? status,
    int? actualReps,
    int? actualDurationSeconds,
    double? actualDistanceMeters,
    double? actualLoadKg,
    double? actualRpe,
    double? actualRir,
    int? actualRecoveryDurationSeconds,
    double? actualRecoveryDistanceMeters,
    WorkoutResultSource? resultSource,
    DateTime? completedAt,
  }) => WorkoutExecutionSet(
    id: id,
    blockOrder: blockOrder,
    blockName: blockName,
    blockFormat: blockFormat,
    blockTimeCapSeconds: blockTimeCapSeconds,
    itemOrder: itemOrder,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    exerciseDescription: exerciseDescription,
    exerciseVideoUrl: exerciseVideoUrl,
    setOrder: setOrder,
    targetReps: targetReps,
    targetDurationSeconds: targetDurationSeconds,
    targetDistanceMeters: targetDistanceMeters,
    targetLoadKg: targetLoadKg,
    targetRpe: targetRpe,
    targetRir: targetRir,
    targetPaceMinSecondsPerKm: targetPaceMinSecondsPerKm,
    targetPaceMaxSecondsPerKm: targetPaceMaxSecondsPerKm,
    recoveryType: recoveryType,
    recoveryDurationSeconds: recoveryDurationSeconds,
    recoveryDistanceMeters: recoveryDistanceMeters,
    restAfterSeconds: restAfterSeconds,
    status: status ?? this.status,
    actualReps: actualReps ?? this.actualReps,
    actualDurationSeconds: actualDurationSeconds ?? this.actualDurationSeconds,
    actualDistanceMeters: actualDistanceMeters ?? this.actualDistanceMeters,
    actualLoadKg: actualLoadKg ?? this.actualLoadKg,
    actualRpe: actualRpe ?? this.actualRpe,
    actualRir: actualRir ?? this.actualRir,
    actualRecoveryDurationSeconds:
        actualRecoveryDurationSeconds ?? this.actualRecoveryDurationSeconds,
    actualRecoveryDistanceMeters:
        actualRecoveryDistanceMeters ?? this.actualRecoveryDistanceMeters,
    resultSource: resultSource ?? this.resultSource,
    completedAt: completedAt ?? this.completedAt,
  );

  @override
  List<Object?> get props => [
    id,
    blockOrder,
    blockName,
    blockFormat,
    blockTimeCapSeconds,
    itemOrder,
    exerciseId,
    exerciseName,
    exerciseDescription,
    exerciseVideoUrl,
    setOrder,
    targetReps,
    targetDurationSeconds,
    targetDistanceMeters,
    targetLoadKg,
    targetRpe,
    targetRir,
    targetPaceMinSecondsPerKm,
    targetPaceMaxSecondsPerKm,
    recoveryType,
    recoveryDurationSeconds,
    recoveryDistanceMeters,
    restAfterSeconds,
    status,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
    actualRecoveryDurationSeconds,
    actualRecoveryDistanceMeters,
    resultSource,
    completedAt,
  ];
}
