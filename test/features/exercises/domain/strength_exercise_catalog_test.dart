import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

Map<String, dynamic> readCatalogJson() {
  final rootFile = File('supabase/catalogs/strength_exercises_v1.json');
  final file = rootFile.existsSync()
      ? rootFile
      : File('../supabase/catalogs/strength_exercises_v1.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> json;
  late StrengthExerciseCatalog catalog;

  setUp(() {
    json = readCatalogJson();
    catalog = StrengthExerciseCatalogCodec.decode(json);
  });

  StrengthExerciseDefinition exercise(String code) =>
      catalog.exercises.singleWhere((entry) => entry.code == code);

  Map<String, dynamic> row(String code) => (json['exercises'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((entry) => entry['code'] == code);

  test(
    'el dominio rechaza carga máxima incompatible sin depender del codec',
    () {
      expect(
        () => StrengthMeasurementOption(
          mode: StrengthMeasurement.maxLoad,
          loadModes: {StrengthLoadMode.bodyweight},
        ),
        throwsFormatException,
      );
      expect(
        () => StrengthExerciseCatalog(version: 1, exercises: []),
        throwsFormatException,
      );
    },
  );

  test('representa los doce casos solicitados sin confundir las métricas', () {
    const cases = [
      (
        'push_up_standard',
        StrengthMeasurement.reps,
        StrengthLoadMode.bodyweight,
      ),
      (
        'push_up_standard',
        StrengthMeasurement.repsInTime,
        StrengthLoadMode.bodyweight,
      ),
      (
        'bench_press_barbell',
        StrengthMeasurement.loadReps,
        StrengthLoadMode.externalLoad,
      ),
      (
        'bench_press_barbell',
        StrengthMeasurement.maxLoad,
        StrengthLoadMode.externalLoad,
      ),
      (
        'pull_up_pronated',
        StrengthMeasurement.reps,
        StrengthLoadMode.bodyweight,
      ),
      (
        'pull_up_weighted',
        StrengthMeasurement.loadReps,
        StrengthLoadMode.bodyweightPlusExternal,
      ),
      (
        'front_plank_forearms',
        StrengthMeasurement.duration,
        StrengthLoadMode.bodyweight,
      ),
      (
        'supinated_flexed_arm_hang',
        StrengthMeasurement.duration,
        StrengthLoadMode.bodyweight,
      ),
      (
        'rope_climb',
        StrengthMeasurement.timeForDistance,
        StrengthLoadMode.bodyweight,
      ),
      (
        'standing_broad_jump',
        StrengthMeasurement.distance,
        StrengthLoadMode.bodyweight,
      ),
      (
        'countermovement_jump',
        StrengthMeasurement.height,
        StrengthLoadMode.bodyweight,
      ),
      (
        'shuttle_5_10_5',
        StrengthMeasurement.timeForCourse,
        StrengthLoadMode.bodyweight,
      ),
    ];
    for (final (code, measurement, load) in cases) {
      expect(exercise(code).supports(measurement, load), isTrue, reason: code);
    }
    expect(
      exercise('front_plank_forearms')
          .supports(StrengthMeasurement.reps, StrengthLoadMode.bodyweight),
      isFalse,
    );
    expect(
      exercise('rope_climb')
          .supports(StrengthMeasurement.maxLoad, StrengthLoadMode.externalLoad),
      isFalse,
    );
  });

  test('mantiene variantes en familia sin igualar mediciones ni cargas', () {
    expect(
      exercise('pull_up_pronated').family,
      exercise('pull_up_weighted').family,
    );
    expect(
      exercise('pull_up_pronated')
          .supports(StrengthMeasurement.loadReps, StrengthLoadMode.bodyweight),
      isFalse,
    );
    expect(
      exercise('pull_up_assisted_band')
          .supports(StrengthMeasurement.reps, StrengthLoadMode.assisted),
      isTrue,
    );
    expect(
      exercise(
        'pull_up_assisted_band',
      ).supports(StrengthMeasurement.loadReps, StrengthLoadMode.externalLoad),
      isFalse,
    );
  });

  test('material obligatorio y opcional tienen efectos distintos', () {
    expect(exercise('push_up_standard').hasRequiredEquipment([]), isTrue);
    expect(
      exercise('bench_press_barbell')
          .hasRequiredEquipment(['bench', 'barbell']),
      isFalse,
    );
    expect(
      exercise('bench_press_barbell')
          .hasRequiredEquipment(['bench', 'barbell', 'plates']),
      isTrue,
    );
    expect(
      exercise('pull_up_assisted_band').hasRequiredEquipment(['pull_up_bar']),
      isFalse,
    );
    expect(
      exercise('pull_up_assisted_machine')
          .hasRequiredEquipment(['pull_up_bar', 'resistance_band']),
      isFalse,
    );
  });

  test('distingue empuje diagonal y COD de tarea reactiva', () {
    expect(exercise('landmine_press_unilateral').movementPatterns, [
      'diagonal_push',
    ]);
    expect(exercise('shuttle_5_10_5').movementPatterns, [
      'change_of_direction',
    ]);
    expect(exercise('reactive_direction_drill').movementPatterns, [
      'reactive_agility',
    ]);
    expect(
      exercise('reactive_direction_drill').requiredEquipment,
      contains('external_cue'),
    );
  });

  test('no genera combinaciones entre medición y carga', () {
    row('push_up_standard')['measurement_options'] = [
      {
        'mode': 'REPS',
        'load_modes': ['bodyweight'],
      },
      {
        'mode': 'LOAD_REPS',
        'load_modes': ['bodyweight_plus_external'],
      },
    ];
    catalog = StrengthExerciseCatalogCodec.decode(json);
    expect(
      exercise('push_up_standard').supports(
        StrengthMeasurement.reps,
        StrengthLoadMode.bodyweightPlusExternal,
      ),
      isFalse,
    );
    expect(
      exercise('push_up_standard')
          .supports(StrengthMeasurement.loadReps, StrengthLoadMode.bodyweight),
      isFalse,
    );
  });

  test(
    'rechaza convertir asistencia o peso corporal en carga máxima externa',
    () {
      for (final load in ['bodyweight', 'assisted']) {
        row('bench_press_barbell')['measurement_options'] = [
          {
            'mode': 'MAX_LOAD',
            'load_modes': [load],
          },
        ];
        expect(
          () => StrengthExerciseCatalogCodec.decode(json),
          throwsFormatException,
        );
      }
    },
  );

  test('rechaza códigos duplicados, versiones y vocabulario desconocido', () {
    (json['exercises'] as List).add(row('push_up_standard'));
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
    json = readCatalogJson();
    json['schema_version'] = 2;
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
    json = readCatalogJson();
    row('push_up_standard')['movement_patterns'] = ['unknown'];
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
    json = readCatalogJson();
    row('push_up_standard')['measurement_options'] = [
      {
        'mode': 'UNKNOWN',
        'load_modes': ['bodyweight'],
      },
    ];
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
  });

  test('rechaza roles solapados y listas vacías de medición', () {
    row('push_up_standard')['required_equipment'] = ['push_up_handles'];
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
    json = readCatalogJson();
    row('push_up_standard')['secondary_muscles'] = ['pectorals'];
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
    json = readCatalogJson();
    row('push_up_standard')['measurement_options'] = [];
    expect(
      () => StrengthExerciseCatalogCodec.decode(json),
      throwsFormatException,
    );
  });

  test('el contrato leído conserva sus colecciones inmutables', () {
    expect(() => catalog.exercises.clear(), throwsUnsupportedError);
    expect(
      () => exercise('push_up_standard').requiredEquipment.add('barbell'),
      throwsUnsupportedError,
    );
    expect(
      () => exercise('push_up_standard').measurements.first.loadModes.clear(),
      throwsUnsupportedError,
    );
  });
}
