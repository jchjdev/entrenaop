import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la ejecución conserva instrucciones de sesión al registrar o leer un histórico antiguo', () {
    final set = <String, dynamic>{
      'id': 'set',
      'block_order': 0,
      'block_name': 'Calentamiento',
      'block_format': 'warm_up',
      'item_order': 0,
      'exercise_id': 'exercise',
      'exercise_name': 'Calentamiento',
      'set_order': 0,
      'rest_after_seconds': 0,
      'status': 'pending',
      'item_instructions': 'Ensaya la salida y los giros despacio.',
    };
    final data = <String, dynamic>{
      'id': 'execution',
      'template_id': 'template',
      'template_name': 'Sesión',
      'template_version': 1,
      'status': 'in_progress',
      'started_at': '2026-10-04T08:00:00Z',
      'workout_execution_sets': [set],
    };
    final execution = WorkoutExecutionModel.fromJson(data);
    expect(execution.sets.single.itemInstructions, set['item_instructions']);
    expect(
      execution.sets.single
          .copyWith(status: WorkoutSetStatus.completed)
          .itemInstructions,
      set['item_instructions'],
    );
    set.remove('item_instructions');
    expect(
      WorkoutExecutionModel.fromJson(data).sets.single.itemInstructions,
      isNull,
    );
  });
}
