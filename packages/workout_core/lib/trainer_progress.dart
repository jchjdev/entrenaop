import 'package:equatable/equatable.dart';

import 'performance_set.dart';
import 'workout_template.dart';

/// Fecha civil, sin convertir zonas horarias ni interpretar una cita como UTC.
/// El adaptador elige la zona del informe antes de extraer año, mes y día.
class TrainerProgressDate extends Equatable
    implements Comparable<TrainerProgressDate> {
  TrainerProgressDate(int year, int month, int day)
    : value = DateTime.utc(year, month, day) {
    if (value.year != year || value.month != month || value.day != day) {
      throw ArgumentError('Fecha civil no válida.');
    }
  }

  factory TrainerProgressDate.fromCalendarDate(DateTime date) =>
      TrainerProgressDate(date.year, date.month, date.day);

  final DateTime value;

  @override
  int compareTo(TrainerProgressDate other) => value.compareTo(other.value);

  @override
  List<Object?> get props => [value];
}

/// Intervalo de fechas civiles [startInclusive, endExclusive).
class TrainerProgressPeriod {
  TrainerProgressPeriod({
    required this.startInclusive,
    required this.endExclusive,
  }) {
    if (startInclusive.compareTo(endExclusive) >= 0) {
      throw ArgumentError('El periodo debe contener al menos un día.');
    }
  }

  final TrainerProgressDate startInclusive;
  final TrainerProgressDate endExclusive;

  bool contains(TrainerProgressDate date) =>
      date.compareTo(startInclusive) >= 0 && date.compareTo(endExclusive) < 0;
}

enum TrainerProgressAssignmentStatus {
  planned,
  inProgress,
  completed,
  skipped,
  abandoned,
  cancelled,
}

/// Adaptación explícita de una pauta; no deduce estados por falta de resultado.
class TrainerProgressAssignment extends Equatable {
  const TrainerProgressAssignment({
    required this.id,
    required this.scheduledDate,
    required this.status,
    this.executionId,
  });

  final String id;
  final TrainerProgressDate scheduledDate;
  final TrainerProgressAssignmentStatus status;
  final String? executionId;

  @override
  List<Object?> get props => [id, scheduledDate, status, executionId];
}

class TrainerComplianceSummary {
  TrainerComplianceSummary._({
    required this.period,
    required this.asOfDate,
    required Map<TrainerProgressAssignmentStatus, int> evaluated,
    required Map<TrainerProgressAssignmentStatus, int> todayAndFuture,
    required this.cancelledExcluded,
  }) : evaluated = Map.unmodifiable(evaluated),
       todayAndFuture = Map.unmodifiable(todayAndFuture);

  final TrainerProgressPeriod period;
  final TrainerProgressDate asOfDate;

  /// Solo pautas anteriores al día de corte o ya completadas, por fecha pautada.
  final Map<TrainerProgressAssignmentStatus, int> evaluated;

  /// Pautas no completadas de hoy en adelante; no penalizan el cumplimiento.
  final Map<TrainerProgressAssignmentStatus, int> todayAndFuture;
  final int cancelledExcluded;

  int get eligibleCount => evaluated.values.fold(0, (a, b) => a + b);
  int get completedCount =>
      evaluated[TrainerProgressAssignmentStatus.completed]!;
  int get pendingCount => evaluated[TrainerProgressAssignmentStatus.planned]!;
  int get inProgressCount =>
      evaluated[TrainerProgressAssignmentStatus.inProgress]!;
  int get skippedCount => evaluated[TrainerProgressAssignmentStatus.skipped]!;
  int get abandonedCount =>
      evaluated[TrainerProgressAssignmentStatus.abandoned]!;
  int get todayAndFutureCount => todayAndFuture.values.fold(0, (a, b) => a + b);

  /// Una cita completada no implica que se completasen todas sus series.
  /// Sin citas evaluables no se inventa un 0 % ni un 100 %.
  double? get completedFraction =>
      eligibleCount == 0 ? null : completedCount / eligibleCount;
}

/// El día de corte aún no está vencido. Completadas adelantadas sí cuentan.
/// La selección es por fecha pautada, no por fecha de ejecución.
TrainerComplianceSummary summarizeTrainerCompliance({
  required Iterable<TrainerProgressAssignment> assignments,
  required TrainerProgressPeriod period,
  required TrainerProgressDate asOfDate,
}) {
  final evaluated = {
    for (final s in TrainerProgressAssignmentStatus.values) s: 0,
  };
  final future = {for (final s in TrainerProgressAssignmentStatus.values) s: 0};
  final executionOwners = <String, String>{};
  var cancelled = 0;
  for (final assignment in _unique(assignments, (a) => a.id)) {
    if (!period.contains(assignment.scheduledDate)) continue;
    final executionId = assignment.executionId;
    if (executionId != null) {
      final previous = executionOwners[executionId];
      if (previous != null && previous != assignment.id) {
        throw ArgumentError('Una ejecución no puede contar en dos pautas.');
      }
      executionOwners[executionId] = assignment.id;
    }
    if (assignment.status == TrainerProgressAssignmentStatus.cancelled) {
      cancelled++;
    } else if (assignment.scheduledDate.compareTo(asOfDate) < 0 ||
        assignment.status == TrainerProgressAssignmentStatus.completed) {
      evaluated[assignment.status] = evaluated[assignment.status]! + 1;
    } else {
      future[assignment.status] = future[assignment.status]! + 1;
    }
  }
  return TrainerComplianceSummary._(
    period: period,
    asOfDate: asOfDate,
    evaluated: evaluated,
    todayAndFuture: future,
    cancelledExcluded: cancelled,
  );
}

enum TrainerProgressSetStatus { pending, completed, skipped }

/// Solo valores realmente registrados: el DTO no contiene objetivos pautados.
/// Los resultados deportivos tipados se conservan con su prescripción para no
/// mezclar pruebas, versiones, protocolos o unidades que no sean comparables.
class TrainerProgressSetRecord extends Equatable {
  const TrainerProgressSetRecord({
    required this.id,
    required this.executionId,
    required this.exerciseId,
    required this.recordDate,
    required this.status,
    required this.blockFormat,
    this.actualReps,
    this.actualDurationSeconds,
    this.actualDistanceMeters,
    this.actualLoadKg,
    this.actualRpe,
    this.actualRir,
    this.performancePrescription,
    this.performanceResult,
  });

  final String id;
  final String executionId;
  final String exerciseId;

  /// Fecha civil de la serie guardada; si no existe, el adaptador debe decidir
  /// y declarar su política antes de incluirla en un informe por periodo.
  final TrainerProgressDate recordDate;
  final TrainerProgressSetStatus status;
  final WorkoutBlockFormat blockFormat;
  final int? actualReps;
  final double? actualDurationSeconds;
  final double? actualDistanceMeters;
  final double? actualLoadKg;
  final double? actualRpe;
  final double? actualRir;
  final PerformanceSetPrescription? performancePrescription;
  final PerformanceSetResult? performanceResult;

  @override
  List<Object?> get props => [
    id,
    executionId,
    exerciseId,
    recordDate,
    status,
    blockFormat,
    actualReps,
    actualDurationSeconds,
    actualDistanceMeters,
    actualLoadKg,
    actualRpe,
    actualRir,
    performancePrescription,
    performanceResult,
  ];
}

/// El AMRAP es un resultado de bloque, no N series inferidas por ejercicio.
class TrainerProgressAmrapRecord extends Equatable {
  const TrainerProgressAmrapRecord({
    required this.executionId,
    required this.blockOrder,
    required this.recordDate,
    required this.completedRounds,
    this.partialItemOrder,
    this.partialReps = 0,
  });

  final String executionId;
  final int blockOrder;
  final TrainerProgressDate recordDate;
  final int completedRounds;
  final int? partialItemOrder;
  final int partialReps;

  @override
  List<Object?> get props => [
    executionId,
    blockOrder,
    recordDate,
    completedRounds,
    partialItemOrder,
    partialReps,
  ];
}

class TrainerRecordedMetricSummary {
  TrainerRecordedMetricSummary._(
    Iterable<num?> observations, {
    bool additive = false,
  }) {
    final values = observations.toList(growable: false);
    final recorded = values.whereType<num>().map((v) => v.toDouble()).toList();
    if (recorded.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Los registros deben ser finitos y no negativos.');
    }
    recorded.sort();
    recordedCount = recorded.length;
    missingCount = values.length - recordedCount;
    minimum = recorded.isEmpty ? null : recorded.first;
    maximum = recorded.isEmpty ? null : recorded.last;
    final sum = recorded.isEmpty ? null : recorded.reduce((a, b) => a + b);
    recordedTotal = additive ? sum : null;
    mean = sum == null ? null : sum / recordedCount;
  }

  late final int recordedCount;
  late final int missingCount;
  late final double? minimum;
  late final double? maximum;
  late final double? mean;

  /// Suma de observaciones conocidas, nunca una estimación de datos ausentes.
  /// Solo se ofrece para repeticiones, duración y distancia. En cargas,
  /// RPE y RIR es null porque sumar esas observaciones no expresa volumen.
  late final double? recordedTotal;
}

class TrainerExerciseProgress {
  TrainerExerciseProgress._(
    this.exerciseId,
    List<TrainerProgressSetRecord> sets,
  ) : records = List.unmodifiable(sets) {
    final completed = sets.where(
      (s) => s.status == TrainerProgressSetStatus.completed,
    );
    reps = TrainerRecordedMetricSummary._(
      completed.map((s) => s.actualReps),
      additive: true,
    );
    durationSeconds = TrainerRecordedMetricSummary._(
      completed.map((s) => s.actualDurationSeconds),
      additive: true,
    );
    distanceMeters = TrainerRecordedMetricSummary._(
      completed.map((s) => s.actualDistanceMeters),
      additive: true,
    );
    loadKg = TrainerRecordedMetricSummary._(
      completed.map((s) => s.actualLoadKg),
    );
    rpe = TrainerRecordedMetricSummary._(completed.map((s) => s.actualRpe));
    rir = TrainerRecordedMetricSummary._(completed.map((s) => s.actualRir));
  }

  final String exerciseId;

  /// No incluye referencias AMRAP. Conserva contexto deportivo y procedencia.
  final List<TrainerProgressSetRecord> records;
  late final TrainerRecordedMetricSummary reps;
  late final TrainerRecordedMetricSummary durationSeconds;
  late final TrainerRecordedMetricSummary distanceMeters;
  late final TrainerRecordedMetricSummary loadKg;
  late final TrainerRecordedMetricSummary rpe;
  late final TrainerRecordedMetricSummary rir;

  int count(TrainerProgressSetStatus status) =>
      records.where((s) => s.status == status).length;
}

class TrainerExerciseResultsSummary {
  TrainerExerciseResultsSummary._({
    required Map<String, TrainerExerciseProgress> exercises,
    required List<TrainerProgressAmrapRecord> amrapBlocks,
    required this.amrapReferenceSetsExcluded,
  }) : exercises = Map.unmodifiable(exercises),
       amrapBlocks = List.unmodifiable(amrapBlocks);

  final Map<String, TrainerExerciseProgress> exercises;
  final List<TrainerProgressAmrapRecord> amrapBlocks;
  final int amrapReferenceSetsExcluded;
}

/// Resume registros por su propia fecha, independiente de la fecha pautada.
/// Incluye series completadas de ejecuciones abandonadas o todavía en curso;
/// el estado de la sesión no borra resultados reales. No calcula récords,
/// tonelaje, calorías ni equivalencias entre identificadores/versiones.
TrainerExerciseResultsSummary summarizeTrainerExerciseResults({
  required Iterable<TrainerProgressSetRecord> sets,
  required TrainerProgressPeriod period,
  Iterable<TrainerProgressAmrapRecord> amrapBlocks = const [],
}) {
  final grouped = <String, List<TrainerProgressSetRecord>>{};
  var references = 0;
  for (final set in _unique(sets, (s) => s.id)) {
    if (!period.contains(set.recordDate)) continue;
    if (set.blockFormat == WorkoutBlockFormat.amrap) {
      references++;
    } else {
      grouped.putIfAbsent(set.exerciseId, () => []).add(set);
    }
  }
  final blocks = _unique(
    amrapBlocks,
    (b) => (b.executionId, b.blockOrder),
  ).where((b) => period.contains(b.recordDate)).toList();
  for (final block in blocks) {
    if (block.completedRounds < 0 ||
        block.partialReps < 0 ||
        block.blockOrder < 0 ||
        (block.partialItemOrder != null && block.partialItemOrder! < 0) ||
        (block.partialReps > 0 && block.partialItemOrder == null)) {
      throw ArgumentError('Resultado AMRAP incoherente.');
    }
  }
  return TrainerExerciseResultsSummary._(
    exercises: {
      for (final entry in grouped.entries)
        entry.key: TrainerExerciseProgress._(entry.key, entry.value),
    },
    amrapBlocks: blocks,
    amrapReferenceSetsExcluded: references,
  );
}

/// Una repetición idéntica puede proceder de páginas solapadas. Dos estados
/// distintos con la misma identidad requieren recargar, no elegir uno al azar.
Iterable<T> _unique<T extends Equatable, K>(
  Iterable<T> records,
  K Function(T) key,
) sync* {
  final seen = <K, T>{};
  for (final record in records) {
    final id = key(record);
    final previous = seen[id];
    if (previous != null) {
      if (previous != record) {
        throw ArgumentError('Registros contradictorios para $id.');
      }
    } else {
      seen[id] = record;
      yield record;
    }
  }
}
