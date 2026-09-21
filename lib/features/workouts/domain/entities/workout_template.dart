import 'package:equatable/equatable.dart';

enum WorkoutBlockFormat {
  straightSets,
  circuit,
  superset,
  intervals,
  emom,
  amrap,
  tabata,
  warmUp,
  coolDown,
}

enum WorkoutTemplateOrigin { system, user, coach, algorithm }

/// Datos ligeros para descubrir una sesión sin cargar todos sus bloques.
class WorkoutTemplateSummary extends Equatable {
  const WorkoutTemplateSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.origin,
    required this.version,
  });

  final String id;
  final String name;
  final String? description;
  final int? estimatedDurationMinutes;
  final WorkoutTemplateOrigin origin;
  final int version;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    estimatedDurationMinutes,
    origin,
    version,
  ];
}

class WorkoutTemplate extends Equatable {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.version,
    required this.blocks,
  });

  final String id;
  final String name;
  final String? description;
  final int? estimatedDurationMinutes;
  final int version;
  final List<WorkoutBlock> blocks;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    estimatedDurationMinutes,
    version,
    blocks,
  ];
}

class WorkoutBlock extends Equatable {
  const WorkoutBlock({
    required this.id,
    required this.name,
    required this.format,
    required this.rounds,
    required this.restAfterSeconds,
    required this.items,
    this.timeCapSeconds,
  });

  final String id;
  final String name;
  final WorkoutBlockFormat format;
  final int rounds;
  final int? timeCapSeconds;
  final int restAfterSeconds;
  final List<WorkoutItem> items;

  @override
  List<Object?> get props => [
    id,
    name,
    format,
    rounds,
    timeCapSeconds,
    restAfterSeconds,
    items,
  ];
}

class WorkoutItem extends Equatable {
  const WorkoutItem({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.exerciseDescription,
    this.notes,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final String? exerciseDescription;
  final String? notes;
  final List<WorkoutSet> sets;

  @override
  List<Object?> get props => [
    id,
    exerciseId,
    exerciseName,
    exerciseDescription,
    notes,
    sets,
  ];
}

class WorkoutSet extends Equatable {
  const WorkoutSet({
    required this.id,
    required this.order,
    required this.restAfterSeconds,
    this.targetReps,
    this.targetDurationSeconds,
    this.targetDistanceMeters,
    this.targetLoadKg,
    this.targetRpe,
    this.targetRir,
  });

  final String id;
  final int order;
  final int? targetReps;
  final int? targetDurationSeconds;
  final double? targetDistanceMeters;
  final double? targetLoadKg;
  final double? targetRpe;
  final double? targetRir;
  final int restAfterSeconds;

  @override
  List<Object?> get props => [
    id,
    order,
    targetReps,
    targetDurationSeconds,
    targetDistanceMeters,
    targetLoadKg,
    targetRpe,
    targetRir,
    restAfterSeconds,
  ];
}
