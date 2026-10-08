import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> record() => {
    'id': 'execution',
    'template_id': 'template',
    'template_name': 'Entrenamiento',
    'template_version': 1,
    'status': 'completed',
    'started_at': '2026-10-08T08:00:00Z',
    'completed_at': '2026-10-08T08:30:00Z',
    'workout_execution_sets': <Map<String, dynamic>>[],
  };

  test('el historial antiguo no se clasifica por nombre ni por sus series', () {
    final data = record()..['template_name'] = 'Carrera y fuerza';
    data['workout_execution_sets'] = [
      {
        'id': 'set',
        'block_order': 0,
        'block_name': 'Carrera',
        'block_format': 'running',
        'item_order': 0,
        'exercise_id': 'exercise',
        'exercise_name': 'Carrera',
        'set_order': 0,
        'rest_after_seconds': 0,
        'status': 'pending',
      },
    ];
    expect(
      WorkoutExecutionModel.fromJson(data).sessionType,
      WorkoutSessionType.unclassified,
    );
    expect(WorkoutExecutionModel.fromJson(data).sessionTypePolicy, isNull);
    data['session_type'] = null;
    expect(
      WorkoutExecutionModel.fromJson(data).sessionType,
      WorkoutSessionType.unclassified,
    );
  });

  for (final type in [
    WorkoutSessionType.running,
    WorkoutSessionType.strength,
    WorkoutSessionType.mixed,
  ]) {
    test('lee y conserva ${type.name} al registrar resultados', () {
      final data = record()
        ..['session_type'] = type.name
        ..['session_type_policy'] = 'block_format_v1';
      final execution = WorkoutExecutionModel.fromJson(data);
      final updated = execution.copyWith(finalRpe: 7, notes: 'Resultado');
      expect(updated.sessionType, type);
      expect(updated.sessionTypePolicy, 'block_format_v1');
      expect(updated.finalRpe, 7);
      expect(
        execution,
        isNot(
          WorkoutExecutionModel.fromJson({
            ...data,
            'session_type': type == WorkoutSessionType.running
                ? 'mixed'
                : 'running',
          }),
        ),
      );
    });
  }

  test(
    'una clasificación inválida no se transforma silenciosamente en fuerza',
    () {
      expect(
        () => WorkoutExecutionModel.fromJson({
          ...record(),
          'session_type': 'invented',
        }),
        throwsFormatException,
      );
    },
  );
}
