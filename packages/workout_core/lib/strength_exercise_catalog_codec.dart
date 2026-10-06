import 'strength_exercise_catalog.dart';

/// Adaptador de datos. El dominio recibe objetos y desconoce JSON y Supabase.
abstract final class StrengthExerciseCatalogCodec {
  static StrengthExerciseCatalog decode(Map<String, dynamic> json) {
    if (json['schema_version'] != 1 || json['catalog_version'] != 1) {
      throw const FormatException('Versión de catálogo no compatible.');
    }
    final rows = json['exercises'];
    if (rows is! List) {
      throw const FormatException('Se esperaba una lista de ejercicios.');
    }
    return StrengthExerciseCatalog(
      version: json['catalog_version'] as int,
      exercises: rows.map((row) => decodeDefinition(_object(row))),
    );
  }

  static StrengthExerciseDefinition decodeDefinition(
    Map<String, dynamic> row, {
    int definitionVersion = 1,
  }) {
    final options = row['measurement_options'];
    if (options is! List) throw const FormatException('Faltan mediciones.');
    final candidate = row['candidate_existing_exercise_id'];
    if (candidate != null && candidate is! String) {
      throw const FormatException('Identificador previo no válido.');
    }
    return StrengthExerciseDefinition(
      code: _text(row, 'code'),
      name: _text(row, 'name'),
      family: _text(row, 'family'),
      definitionVersion: definitionVersion,
      movementPatterns: _tags(row, 'movement_patterns'),
      movementModes: _tags(row, 'movement_modes'),
      bodyRegions: _tags(row, 'body_regions'),
      laterality: _text(row, 'laterality'),
      technicalLevel: _text(row, 'technical_level'),
      requiredEquipment: _tags(row, 'required_equipment'),
      optionalEquipment: _tags(row, 'optional_equipment'),
      primaryMuscles: _tags(row, 'primary_muscles'),
      secondaryMuscles: _tags(row, 'secondary_muscles'),
      progressionAxes: _tags(row, 'progression_axes'),
      notes: _text(row, 'notes'),
      candidateExistingExerciseId: candidate as String?,
      measurements: options.map((value) {
        final option = _object(value);
        final loads = _tags(option, 'load_modes');
        if (loads.toSet().length != loads.length) {
          throw const FormatException('Modos de carga duplicados.');
        }
        return StrengthMeasurementOption(
          mode: _enumValue(
            StrengthMeasurement.values,
            option['mode'],
            (mode) => mode.code,
          ),
          loadModes: loads
              .map(
                (load) => _enumValue(
                  StrengthLoadMode.values,
                  load,
                  (mode) => mode.code,
                ),
              )
              .toSet(),
        );
      }),
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Se esperaba un objeto.');
    }
    return value;
  }

  static String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('Texto no válido: $key.');
    return value;
  }

  static List<String> _tags(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List || value.any((tag) => tag is! String)) {
      throw FormatException('Lista no válida: $key.');
    }
    return value.cast<String>();
  }

  static T _enumValue<T>(
    List<T> values,
    Object? code,
    String Function(T) getCode,
  ) {
    for (final value in values) {
      if (getCode(value) == code) return value;
    }
    throw FormatException('Código desconocido: $code.');
  }
}
