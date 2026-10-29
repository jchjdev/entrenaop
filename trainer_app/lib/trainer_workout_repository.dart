import 'package:workout_core/workout_result_review.dart';

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_core/workout_template_query.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';

import 'trainer_exercise_repository.dart';

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
      isRunning = row['is_running'] == true,
      createdAt = DateTime.parse(row['created_at'] as String);
  final String id, name;
  final int version;
  final bool isRunning;
  final DateTime createdAt;
}

enum TrainerAssignmentVisibility {
  current('Habitual'),
  withdrawn('Retiradas'),
  archived('Archivadas'),
  all('Todas');

  const TrainerAssignmentVisibility(this.label);
  final String label;
}

enum TrainerAssignmentLifecycleAction { archive, restore, delete }

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
      note = row['note'] as String?,
      revision = (row['planning_revision'] as num?)?.toInt() ?? 0,
      resultRevision = (row['result_revision'] as num?)?.toInt() ?? 0,
      archiveRevision = (row['archive_revision'] as num?)?.toInt() ?? 0,
      archivedAt = row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
      deleteBlockReason = row['delete_block_reason'] as String?;
  final String id, templateId, name, status;
  final String? executionId, note;
  final int version, revision, resultRevision;
  final DateTime date, createdAt;
  final DateTime? archivedAt;
  final int archiveRevision;
  final String? deleteBlockReason;
  bool get archived => archivedAt != null;
  String? get deletionExplanation =>
      executionId != null ||
          resultRevision > 0 ||
          deleteBlockReason == 'results'
      ? 'Tiene una ejecución o resultados. Puedes archivarla.'
      : switch (deleteBlockReason) {
          'garmin' => 'Garmin no tiene la retirada confirmada o conserva operaciones pendientes. Puedes archivarla.',
          'references' => 'Conserva conversaciones, vídeos u otras referencias. Puedes archivarla.',
          null => status == 'cancelled' ? null : 'Retira primero la pauta.',
          _ => 'Actualiza la planificación antes de continuar.',
        };
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
  Future<List<WorkoutEditorExercise>> exercises({
    Set<String> retainedIds = const {},
  });
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
    TrainerAssignmentVisibility visibility = TrainerAssignmentVisibility.all,
  });
  Future<WorkoutJson?> result(String assignmentId);
  Future<void> cancel(String assignmentId);
  Future<void> changeLifecycle({
    required String operationId,
    required TrainerAssignment assignment,
    required TrainerAssignmentLifecycleAction action,
  });
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
    final value = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: params,
    );
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
  Future<List<WorkoutEditorExercise>> exercises({
    Set<String> retainedIds = const {},
  }) async {
    final result = <WorkoutEditorExercise>[];
    final repository = SupabaseTrainerExerciseRepository(client, userId);
    final official = await repository.officialCatalog();
    result.addAll(
      official
          .where((e) => e.id != runningExerciseId)
          .map(
            (e) => WorkoutEditorExercise(
              id: e.id,
              name: e.draft.name,
              muscleGroups: e.draft.muscleGroups,
              equipment: e.draft.equipment,
              thumbnailUrl: e.imageUrl,
              catalogScope: 'EntrenaOP',
            ),
          ),
    );
    final own = await repository.list();
    result.addAll(
      own
          .where((e) => e.current || retainedIds.contains(e.id))
          .map(
            (e) => WorkoutEditorExercise(
              id: e.id,
              name: e.current
                  ? e.draft.name
                  : '${e.draft.name} (versión ${e.version})',
              muscleGroups: e.draft.muscleGroups,
              equipment: e.draft.equipment,
              thumbnailUrl: e.imageUrl,
              catalogScope: 'Míos',
            ),
          ),
    );
    return result;
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
    TrainerAssignmentVisibility visibility = TrainerAssignmentVisibility.all,
  }) async =>
      (await _rpc('list_trainer_assignments_filtered', {
            'p_expected_owner': userId,
            'p_visibility': visibility.name,
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

  @override
  Future<void> changeLifecycle({
    required String operationId,
    required TrainerAssignment assignment,
    required TrainerAssignmentLifecycleAction action,
  }) async {
    await _rpc('change_trainer_assignment_lifecycle', {
      'p_expected_owner': userId,
      'p_operation_id': operationId,
      'p_id': assignment.id,
      'p_revision': assignment.archiveRevision,
      'p_action': action.name,
    });
  }
}

/// Solo consulta pautas del alumno accesibles mediante el contrato profesional.
Future<ReviewHistoryPage> loadTrainerComparisonPage(
  TrainerWorkoutRepository repository,
  WorkoutJson current,
  Object? cursor,
) async {
  final clientId = current['user_id'] as String?;
  if (clientId == null) throw StateError('Falta la identidad del alumno.');
  final rows = await repository.assignments(
    clientId,
    before: cursor as TrainerAssignment?,
  );
  final snapshot = reviewSessionFromJson(current);
  final sessions = <ReviewSession>[];
  for (final assignment in rows) {
    if (assignment.templateId != snapshot.templateId ||
        assignment.version != snapshot.version ||
        assignment.executionId == snapshot.id ||
        !['completed', 'abandoned'].contains(assignment.status)) {
      continue;
    }
    final result = await repository.result(assignment.id);
    if (result == null || result['user_id'] != clientId) continue;
    final session = reviewSessionFromJson(result);
    if (snapshot.canCompare(session)) sessions.add(session);
  }
  return ReviewHistoryPage(
    sessions,
    nextCursor: rows.length == 50 ? rows.last : null,
  );
}
