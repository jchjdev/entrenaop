import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/workout_template_query.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';

typedef WorkoutJson = Map<String, dynamic>;

String trainerOperationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class TrainerWorkout {
  TrainerWorkout.fromJson(WorkoutJson row)
    : id = row['id'] as String,
      name = row['name'] as String,
      version = row['version'] as int,
      createdAt = DateTime.parse(row['created_at'] as String);
  final String id, name;
  final int version;
  final DateTime createdAt;
}

class TrainerAssignment {
  TrainerAssignment.fromJson(WorkoutJson row)
    : id = row['id'] as String,
      templateId = row['template_id'] as String,
      name = row['template_name'] as String,
      version = row['template_version'] as int,
      date = DateTime.parse(row['scheduled_date'] as String),
      createdAt = DateTime.parse(row['created_at'] as String),
      status = row['status'] as String,
      executionId = row['execution_id'] as String?,
      note = row['note'] as String?;
  final String id, templateId, name, status;
  final String? executionId, note;
  final int version;
  final DateTime date, createdAt;
  String get statusLabel => switch (status) {
    'planned' => 'Pendiente',
    'in_progress' => 'En curso',
    'completed' => 'Completada',
    'abandoned' => 'Abandonada',
    'skipped' => 'Omitida',
    'cancelled' => 'Retirada',
    _ => 'Estado desconocido',
  };
}

abstract class TrainerWorkoutRepository {
  Future<List<TrainerWorkout>> workouts({TrainerWorkout? before});
  Future<WorkoutTemplate?> template(String id);
  Future<List<WorkoutEditorExercise>> exercises();
  Future<String> save(
    String operationId,
    CreatePersonalWorkoutInput input, {
    String? previousId,
  });
  Future<void> assign({
    required String id,
    required String relationId,
    required String templateId,
    required DateTime date,
    String? note,
  });
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
  });
  Future<WorkoutJson?> result(String assignmentId);
  Future<void> cancel(String assignmentId);
}

class SupabaseTrainerWorkoutRepository implements TrainerWorkoutRepository {
  const SupabaseTrainerWorkoutRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, WorkoutJson params) async {
    _identity();
    final value = await client.rpc(name, params: params);
    _identity();
    return value;
  }

  @override
  Future<List<TrainerWorkout>> workouts({TrainerWorkout? before}) async =>
      (await _rpc('list_trainer_workouts', {
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map((v) => TrainerWorkout.fromJson(WorkoutJson.from(v as Map)))
          .toList();
  @override
  Future<WorkoutTemplate?> template(String id) async {
    _identity();
    final row = await client
        .from('workout_templates')
        .select(workoutTemplateSelect)
        .eq('id', id)
        .maybeSingle();
    _identity();
    return row == null ? null : WorkoutTemplateModel.fromJson(row);
  }

  @override
  Future<List<WorkoutEditorExercise>> exercises() async {
    final result = <WorkoutEditorExercise>[];
    for (var offset = 0; ; offset += 500) {
      _identity();
      final rows = await client
          .from('exercises')
          .select('id,name,muscle_groups,equipment,thumbnail_url')
          .eq('is_public', true)
          .order('id')
          .range(offset, offset + 499);
      _identity();
      result.addAll(
        rows.map(
          (row) => WorkoutEditorExercise(
            id: row['id'] as String,
            name: row['name'] as String,
            muscleGroups: (row['muscle_groups'] as List? ?? []).cast<String>(),
            equipment: (row['equipment'] as List? ?? []).cast<String>(),
            thumbnailUrl: row['thumbnail_url'] as String?,
          ),
        ),
      );
      if (rows.length < 500) return result;
    }
  }

  @override
  Future<String> save(
    String operationId,
    CreatePersonalWorkoutInput input, {
    String? previousId,
  }) async {
    validateWorkoutDraft(input);
    return await _rpc('save_trainer_workout', {
      'p_operation_id': operationId,
      'p_payload': workoutDraftToJson(input),
      'p_previous_id': previousId,
    }) as String;
  }

  @override
  Future<void> assign({
    required String id,
    required String relationId,
    required String templateId,
    required DateTime date,
    String? note,
  }) async {
    await _rpc('assign_trainer_workout', {
      'p_id': id,
      'p_relation_id': relationId,
      'p_template_id': templateId,
      'p_date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'p_note': note,
    });
  }

  @override
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
  }) async =>
      (await _rpc('list_trainer_assignments', {
            'p_client_id': clientId,
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map((v) => TrainerAssignment.fromJson(WorkoutJson.from(v as Map)))
          .toList();
  @override
  Future<WorkoutJson?> result(String assignmentId) async {
    final row = await _rpc('get_trainer_assignment_result', {
      'p_id': assignmentId,
    });
    return row == null ? null : WorkoutJson.from(row as Map);
  }

  @override
  Future<void> cancel(String assignmentId) async {
    await _rpc('cancel_trainer_assignment', {'p_id': assignmentId});
  }
}
