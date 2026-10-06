import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../test/features/exercises/domain/strength_exercise_catalog_test.dart'
    show readCatalogJson;

void main() {
  Map<String, dynamic> exerciseJson() => {
    'id': '20000000-0000-4000-8000-000000000001',
    'name': 'Flexiones',
    'difficulty': 'inicial',
    'exercise_type': 'repeticiones',
    'training_profile': {
      'definition_version': 2,
      'definition': (readCatalogJson()['exercises'] as List).singleWhere(
        (row) => row['code'] == 'push_up_standard',
      ),
    },
  };

  test(
    'ADMIN lee la misma definición versionada sin modificar el borrador',
    () {
      final exercise = AdminCatalogExercise.fromJson(exerciseJson());
      expect(exercise.trainingProfile!.code, 'push_up_standard');
      expect(exercise.trainingProfile!.definitionVersion, 2);
      expect(exercise.toDraft().name, 'Flexiones');
    },
  );

  test('ADMIN conserva compatibilidad con ejercicios sin perfil deportivo', () {
    final json = exerciseJson()..remove('training_profile');
    expect(AdminCatalogExercise.fromJson(json).trainingProfile, isNull);
  });
}
