import 'package:entrenaop/features/workouts/data/models/workout_template_model.dart';
import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte el resumen ligero usado por la biblioteca', () {
    final summary = WorkoutTemplateSummaryModel.fromJson(const {
      'id': 'template-1',
      'name': 'Fuerza base',
      'description': 'Sesión pública',
      'estimated_duration_minutes': 20,
      'origin': 'system',
      'version': 2,
    });

    expect(summary.name, 'Fuerza base');
    expect(summary.origin, WorkoutTemplateOrigin.system);
    expect(summary.version, 2);
  });

  test('convierte y ordena la jerarquía completa de una plantilla', () {
    final workout = WorkoutTemplateModel.fromJson({
      'id': 'template-1',
      'name': 'Fuerza base',
      'description': 'Sesión de prueba',
      'estimated_duration_minutes': 20,
      'version': 1,
      'workout_blocks': [
        {
          'id': 'block-2',
          'order_index': 1,
          'name': 'Trabajo principal',
          'format': 'straight_sets',
          'rounds': 1,
          'time_cap_seconds': null,
          'rest_after_seconds': 0,
          'workout_items': [
            {
              'id': 'item-1',
              'order_index': 0,
              'notes': 'Mantén la técnica',
              'exercises': {
                'id': 'exercise-1',
                'name': 'Flexiones',
                'description': 'Cuerpo alineado',
              },
              'workout_sets': [
                {
                  'id': 'set-2',
                  'order_index': 1,
                  'target_reps': 8,
                  'target_duration_seconds': null,
                  'target_distance_meters': null,
                  'target_load_kg': null,
                  'target_rpe': null,
                  'target_rir': 3,
                  'rest_after_seconds': 0,
                },
                {
                  'id': 'set-1',
                  'order_index': 0,
                  'target_reps': 8,
                  'target_duration_seconds': null,
                  'target_distance_meters': null,
                  'target_load_kg': null,
                  'target_rpe': null,
                  'target_rir': 3,
                  'rest_after_seconds': 60,
                },
              ],
            },
          ],
        },
        {
          'id': 'block-1',
          'order_index': 0,
          'name': 'Activación',
          'format': 'warm_up',
          'rounds': 1,
          'time_cap_seconds': 300,
          'rest_after_seconds': 30,
          'workout_items': <Map<String, dynamic>>[],
        },
      ],
    });

    expect(workout.blocks.first.name, 'Activación');
    expect(workout.blocks.last.format, WorkoutBlockFormat.straightSets);
    expect(workout.blocks.last.items.single.exerciseName, 'Flexiones');
    expect(workout.blocks.last.items.single.sets.first.id, 'set-1');
    expect(workout.blocks.last.items.single.sets.last.targetRir, 3);
  });

  test('rechaza un formato de bloque que el motor todavía no soporta', () {
    expect(
      () => WorkoutTemplateModel.fromJson({
        'id': 'template-1',
        'name': 'Sesión inválida',
        'description': null,
        'estimated_duration_minutes': null,
        'version': 1,
        'workout_blocks': [
          {
            'id': 'block-1',
            'order_index': 0,
            'name': 'Desconocido',
            'format': 'formato_inventado',
            'rounds': 1,
            'time_cap_seconds': null,
            'rest_after_seconds': 0,
            'workout_items': <Map<String, dynamic>>[],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('ordena una ejecución y localiza la siguiente serie pendiente', () {
    Map<String, dynamic> result({
      required String id,
      required int order,
      required String status,
    }) => {
      'id': id,
      'block_order': 0,
      'block_name': 'Principal',
      'item_order': 0,
      'exercise_id': 'exercise-1',
      'exercise_name': 'Flexiones',
      'exercise_description': 'Mantén el cuerpo alineado.',
      'exercise_video_url': 'https://example.com/flexiones.mp4',
      'set_order': order,
      'target_reps': 8,
      'target_duration_seconds': null,
      'target_distance_meters': null,
      'target_load_kg': null,
      'target_rpe': null,
      'target_rir': 3,
      'rest_after_seconds': 60,
      'status': status,
      'actual_reps': status == 'completed' ? 8 : null,
      'actual_duration_seconds': null,
      'actual_distance_meters': null,
      'actual_load_kg': null,
      'actual_rpe': null,
      'actual_rir': null,
      'completed_at': status == 'pending' ? null : '2026-09-20T18:05:00Z',
    };

    final execution = WorkoutExecutionModel.fromJson({
      'id': 'execution-1',
      'template_id': 'template-1',
      'template_name': 'Fuerza base',
      'template_version': 1,
      'status': 'in_progress',
      'started_at': '2026-09-20T18:00:00Z',
      'completed_at': null,
      'final_rpe': null,
      'notes': null,
      'abandonment_reason': null,
      'workout_execution_sets': [
        result(id: 'set-3', order: 2, status: 'skipped'),
        result(id: 'set-2', order: 1, status: 'pending'),
        result(id: 'set-1', order: 0, status: 'completed'),
      ],
    });

    expect(execution.completedSetCount, 1);
    expect(execution.skippedSetCount, 1);
    expect(execution.resolvedSetCount, 2);
    expect(execution.currentSet?.id, 'set-2');
    expect(execution.currentSet?.status, WorkoutSetStatus.pending);
    expect(
      execution.sets.first.exerciseDescription,
      'Mantén el cuerpo alineado.',
    );
    expect(
      execution.sets.first.exerciseVideoUrl,
      'https://example.com/flexiones.mp4',
    );
    expect(
      execution.sets.first.canBeCorrectedAt(
        DateTime.parse('2026-09-21T18:04:59Z'),
      ),
      isTrue,
    );
    expect(
      execution.sets.first.canBeCorrectedAt(
        DateTime.parse('2026-09-21T18:05:01Z'),
      ),
      isFalse,
    );
  });

  test('interpreta una ejecución abandonada y conserva su motivo', () {
    final execution = WorkoutExecutionModel.fromJson({
      'id': 'execution-2',
      'template_id': 'template-1',
      'template_name': 'Fuerza base',
      'template_version': 1,
      'status': 'abandoned',
      'started_at': '2026-09-20T18:00:00Z',
      'completed_at': '2026-09-20T18:10:00Z',
      'final_rpe': null,
      'notes': null,
      'abandonment_reason': 'lack_of_time',
      'workout_execution_sets': const <Map<String, dynamic>>[],
    });

    expect(execution.status, WorkoutExecutionStatus.abandoned);
    expect(execution.abandonmentReason, WorkoutAbandonmentReason.lackOfTime);
  });

  test('ordena una superserie por rondas y no por ejercicio', () {
    Map<String, dynamic> groupedSet({
      required String id,
      required int item,
      required int round,
    }) => {
      'id': id,
      'block_order': 0,
      'block_name': 'Superserie principal',
      'block_format': 'superset',
      'item_order': item,
      'exercise_id': 'exercise-$item',
      'exercise_name': 'Ejercicio $item',
      'exercise_description': null,
      'exercise_video_url': null,
      'set_order': round,
      'target_reps': 10,
      'target_duration_seconds': null,
      'target_distance_meters': null,
      'target_load_kg': null,
      'target_rpe': null,
      'target_rir': null,
      'rest_after_seconds': item == 1 ? 90 : 0,
      'status': 'pending',
      'actual_reps': null,
      'actual_duration_seconds': null,
      'actual_distance_meters': null,
      'actual_load_kg': null,
      'actual_rpe': null,
      'actual_rir': null,
      'completed_at': null,
    };

    final execution = WorkoutExecutionModel.fromJson({
      'id': 'execution-grouped',
      'template_id': 'template-grouped',
      'template_name': 'Superserie',
      'template_version': 1,
      'status': 'in_progress',
      'started_at': '2026-09-21T18:00:00Z',
      'completed_at': null,
      'final_rpe': null,
      'notes': null,
      'abandonment_reason': null,
      'workout_execution_sets': [
        groupedSet(id: 'b2', item: 1, round: 1),
        groupedSet(id: 'a2', item: 0, round: 1),
        groupedSet(id: 'b1', item: 1, round: 0),
        groupedSet(id: 'a1', item: 0, round: 0),
      ],
    });

    expect(execution.sets.map((set) => set.id), ['a1', 'b1', 'a2', 'b2']);
    expect(execution.currentSet?.roundNumber, 1);
    expect(execution.sets[1].restAfterSeconds, 90);
  });
}
