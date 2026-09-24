import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_draft.dart';

void main() {
  test('normaliza el mismo borrador para cualquier contexto de guardado', () {
    final result = ExerciseDraftValidator.normalizeAndValidate(
      const ExerciseDraft(
        name: '  Press francés  ',
        description: '  Controla la bajada.  ',
        videoUrl: ' https://example.com/video ',
        muscleGroups: [' Tríceps ', 'tríceps'],
        equipment: [' Mancuerna ', ''],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
      ),
    );

    expect(result.name, 'Press francés');
    expect(result.description, 'Controla la bajada.');
    expect(result.videoUrl, 'https://example.com/video');
    expect(result.muscleGroups, ['tríceps']);
    expect(result.equipment, ['mancuerna']);
  });

  test('rechaza etiquetas que el contrato SQL tampoco admite', () {
    expect(
      () => ExerciseDraftValidator.normalizeAndValidate(
        ExerciseDraft(
          name: 'Ejercicio válido',
          muscleGroups: [List.filled(41, 'x').join()],
          equipment: const [],
          difficulty: 'inicial',
          exerciseType: 'duración',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
