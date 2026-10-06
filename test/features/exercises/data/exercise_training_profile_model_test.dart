import 'package:entrenaop/features/exercises/data/models/exercise_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/strength_exercise_catalog_test.dart' show readCatalogJson;

void main() {
  Map<String, dynamic> exerciseJson({bool withProfile = true}) => {
    'id': '20000000-0000-4000-8000-000000000001',
    'name': 'Flexiones',
    'muscle_groups': ['pecho'],
    'equipment': ['peso corporal'],
    'difficulty': 'inicial',
    'exercise_type': 'repeticiones',
    'is_public': true,
    'origin': 'system',
    'training_profile': withProfile
        ? {
            'definition_version': 2,
            'definition': (readCatalogJson()['exercises'] as List).singleWhere(
              (row) => row['code'] == 'push_up_standard',
            ),
          }
        : null,
  };

  test('lee la versión enlazada y la conserva al adaptar la entidad', () {
    final model = ExerciseModel.fromJson(exerciseJson());
    expect(model.trainingProfile!.code, 'push_up_standard');
    expect(model.trainingProfile!.definitionVersion, 2);
    expect(
      ExerciseModel.fromEntity(model).trainingProfile,
      model.trainingProfile,
    );
  });

  test('los campos oficiales no entran en las escrituras personales', () {
    final json = ExerciseModel.fromJson(exerciseJson()).toJson();
    expect(json.containsKey('training_profile'), isFalse);
    expect(json.containsKey('training_profile_code'), isFalse);
    expect(json.containsKey('training_profile_version'), isFalse);
  });

  test('el ejercicio simple sigue admitiendo ausencia de metadatos', () {
    final json = exerciseJson(withProfile: false)
      ..['origin'] = 'user'
      ..['is_public'] = false
      ..['created_by'] = 'user-id';
    expect(ExerciseModel.fromJson(json).trainingProfile, isNull);
    json.remove('training_profile');
    expect(ExerciseModel.fromJson(json).trainingProfile, isNull);
  });
}
