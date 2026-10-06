import 'package:equatable/equatable.dart';

/// Capacidades de medición, independientes de la prescripción deportiva.
enum StrengthMeasurement {
  reps('REPS'),
  loadReps('LOAD_REPS'),
  duration('DURATION'),
  repsInTime('REPS_IN_TIME'),
  maxLoad('MAX_LOAD'),
  timeForDistance('TIME_FOR_DISTANCE'),
  timeForCourse('TIME_FOR_COURSE'),
  distance('DISTANCE'),
  height('HEIGHT'),
  passFail('PASS_FAIL'),
  reactiveMetrics('REACTIVE_METRICS');

  const StrengthMeasurement(this.code);
  final String code;
}

enum StrengthLoadMode {
  bodyweight('bodyweight'),
  externalLoad('external_load'),
  bodyweightPlusExternal('bodyweight_plus_external'),
  assisted('assisted');

  const StrengthLoadMode(this.code);
  final String code;
}

class StrengthMeasurementOption extends Equatable {
  StrengthMeasurementOption({
    required this.mode,
    required Set<StrengthLoadMode> loadModes,
  }) : loadModes = Set.unmodifiable(loadModes) {
    if (loadModes.isEmpty ||
        ((mode == StrengthMeasurement.loadReps ||
                mode == StrengthMeasurement.maxLoad) &&
            loadModes.any(
              (load) =>
                  load != StrengthLoadMode.externalLoad &&
                  load != StrengthLoadMode.bodyweightPlusExternal,
            ))) {
      throw const FormatException('La medición y la carga no son compatibles.');
    }
  }
  final StrengthMeasurement mode;
  final Set<StrengthLoadMode> loadModes;
  bool supports(StrengthLoadMode loadMode) => loadModes.contains(loadMode);
  @override
  List<Object?> get props => [mode, loadModes];
}

/// Una familia agrupa variantes sin garantizar equivalencia de resultados.
class StrengthExerciseDefinition extends Equatable {
  StrengthExerciseDefinition({
    required this.code,
    required this.name,
    required this.family,
    required Iterable<String> movementPatterns,
    required Iterable<String> movementModes,
    required Iterable<String> bodyRegions,
    required this.laterality,
    required this.technicalLevel,
    required Iterable<String> requiredEquipment,
    required Iterable<String> optionalEquipment,
    required Iterable<String> primaryMuscles,
    required Iterable<String> secondaryMuscles,
    required Iterable<StrengthMeasurementOption> measurements,
    required Iterable<String> progressionAxes,
    required this.notes,
    this.definitionVersion = 1,
    this.candidateExistingExerciseId,
  }) : movementPatterns = List.unmodifiable(movementPatterns),
       movementModes = List.unmodifiable(movementModes),
       bodyRegions = List.unmodifiable(bodyRegions),
       requiredEquipment = List.unmodifiable(requiredEquipment),
       optionalEquipment = List.unmodifiable(optionalEquipment),
       primaryMuscles = List.unmodifiable(primaryMuscles),
       secondaryMuscles = List.unmodifiable(secondaryMuscles),
       measurements = List.unmodifiable(measurements),
       progressionAxes = List.unmodifiable(progressionAxes) {
    _checkIdentifier(code);
    _checkIdentifier(family);
    if (definitionVersion < 1 ||
        name.trim().isEmpty ||
        name != name.trim() ||
        notes.trim().isEmpty ||
        notes != notes.trim()) {
      throw const FormatException('Definición de ejercicio no válida.');
    }
    _checkTags(
      this.movementPatterns,
      required: true,
      allowed: allowedMovementPatterns,
    );
    _checkTags(
      this.movementModes,
      required: true,
      allowed: {'dynamic', 'isometric', 'plyometric', 'locomotor'},
    );
    _checkTags(
      this.bodyRegions,
      required: true,
      allowed: {'upper_body', 'lower_body', 'trunk'},
    );
    _checkTags(this.requiredEquipment);
    _checkTags(this.optionalEquipment);
    _checkTags(this.primaryMuscles, required: true);
    _checkTags(this.secondaryMuscles);
    _checkTags(
      this.progressionAxes,
      required: true,
      allowed: allowedProgressionAxes,
    );
    if (!{'bilateral', 'unilateral', 'alternating'}.contains(laterality) ||
        !{'initial', 'intermediate', 'advanced'}.contains(technicalLevel) ||
        this.requiredEquipment.any(this.optionalEquipment.contains) ||
        this.primaryMuscles.any(this.secondaryMuscles.contains) ||
        this.measurements.isEmpty ||
        this.measurements.map((value) => value.mode).toSet().length !=
            this.measurements.length) {
      throw const FormatException(
        'Roles o capacidades de ejercicio no válidos.',
      );
    }
    if (candidateExistingExerciseId != null &&
        !RegExp(
          r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
        ).hasMatch(candidateExistingExerciseId!)) {
      throw const FormatException('Identificador previo no válido.');
    }
  }

  final String code;
  final int definitionVersion;
  final String name;
  final String family;
  final List<String> movementPatterns;
  final List<String> movementModes;
  final List<String> bodyRegions;
  final String laterality;
  final String technicalLevel;
  final List<String> requiredEquipment;
  final List<String> optionalEquipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<StrengthMeasurementOption> measurements;
  final List<String> progressionAxes;
  final String notes;

  /// Candidato editorial; no constituye un enlace operativo.
  final String? candidateExistingExerciseId;

  bool supports(StrengthMeasurement mode, StrengthLoadMode loadMode) =>
      measurements.any(
        (option) => option.mode == mode && option.supports(loadMode),
      );

  bool hasRequiredEquipment(Iterable<String> available) =>
      available.toSet().containsAll(requiredEquipment);

  @override
  List<Object?> get props => [
    code,
    definitionVersion,
    name,
    family,
    movementPatterns,
    movementModes,
    bodyRegions,
    laterality,
    technicalLevel,
    requiredEquipment,
    optionalEquipment,
    primaryMuscles,
    secondaryMuscles,
    measurements,
    progressionAxes,
    notes,
    candidateExistingExerciseId,
  ];

  static const allowedMovementPatterns = {
    'horizontal_push',
    'diagonal_push',
    'vertical_push',
    'vertical_pull',
    'horizontal_pull',
    'squat',
    'hinge',
    'hip_extension',
    'unilateral_knee_dominant',
    'carry',
    'rope_climb',
    'grip_hold',
    'knee_flexion',
    'plantar_flexion',
    'core_anti_extension',
    'core_anti_rotation',
    'core_lateral',
    'plyometric_vertical',
    'plyometric_horizontal',
    'plyometric_lateral',
    'change_of_direction',
    'reactive_agility',
    'ballistic_throw',
  };
  static const allowedProgressionAxes = {
    'load',
    'reps',
    'sets',
    'duration',
    'assistance',
    'distance',
    'density',
    'rest',
    'velocity',
    'contact_time',
    'box_height',
    'complexity',
    'rom',
    'lever',
    'specificity',
    'technique',
  };
}

class StrengthExerciseCatalog {
  StrengthExerciseCatalog({
    required this.version,
    required Iterable<StrengthExerciseDefinition> exercises,
  }) : exercises = List.unmodifiable(exercises) {
    if (version < 1 ||
        this.exercises.isEmpty ||
        this.exercises.map((value) => value.code).toSet().length !=
            this.exercises.length) {
      throw const FormatException(
        'Versión o ejercicios de catálogo no válidos.',
      );
    }
  }
  final int version;
  final List<StrengthExerciseDefinition> exercises;
}

void _checkIdentifier(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_]{1,63}$').hasMatch(value)) {
    throw const FormatException('Código no válido.');
  }
}

void _checkTags(
  List<String> tags, {
  bool required = false,
  Set<String>? allowed,
}) {
  if ((required && tags.isEmpty) ||
      tags.toSet().length != tags.length ||
      tags.any(
        (value) =>
            !RegExp(r'^[a-z][a-z0-9_]{1,63}$').hasMatch(value) ||
            (allowed != null && !allowed.contains(value)),
      )) {
    throw const FormatException('Lista de metadatos no válida.');
  }
}
