import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/workout_draft_codec.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';

import 'trainer_calendar_date.dart';
import 'trainer_workout_repository.dart';

class TrainerAssignmentContext {
  TrainerAssignmentContext.fromJson(WorkoutJson row)
    : assignment = TrainerAssignment.fromJson(row),
      clientId = row['client_id'] as String,
      clientName = row['client_name'] as String,
      relationId = row['relation_id'] as String;
  final TrainerAssignment assignment;
  final String clientId, clientName, relationId;
}

class TrainerReviewItem {
  TrainerReviewItem.fromJson(WorkoutJson row)
    : assignment = TrainerAssignment.fromJson(row),
      clientId = row['client_id'] as String,
      clientName = row['client_name'] as String,
      changedAt = DateTime.parse(row['result_changed_at'] as String);
  final TrainerAssignment assignment;
  final String clientId, clientName;
  final DateTime changedAt;
}

class TrainerAssignmentChangePreview {
  const TrainerAssignmentChangePreview({
    required this.fingerprint,
    required this.hasDateCoincidence,
  });
  final String fingerprint;
  final bool hasDateCoincidence;
}

abstract class TrainerOperationsRepository {
  Future<TrainerAssignmentContext> assignment(String id);
  Future<void> change({
    required String operationId,
    required TrainerAssignment assignment,
    required DateTime date,
    required String fingerprint,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  });
  Future<TrainerAssignmentChangePreview> previewChange({
    required TrainerAssignment assignment,
    required DateTime date,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  });
  Future<List<TrainerReviewItem>> reviews({TrainerReviewItem? before});
  Future<void> markReviewed({
    required String operationId,
    required String assignmentId,
    required int resultRevision,
    String? privateNote,
  });
}

class SupabaseTrainerOperationsRepository
    implements TrainerOperationsRepository {
  const SupabaseTrainerOperationsRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;

  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _identity();
    try {
      final result = await client.rpc(name, params: params);
      _identity();
      return result;
    } catch (_) {
      _identity();
      rethrow;
    }
  }

  @override
  Future<TrainerAssignmentContext> assignment(String id) async =>
      TrainerAssignmentContext.fromJson(
        WorkoutJson.from(
          await _rpc('get_trainer_assignment', {'p_id': id}) as Map,
        ),
      );

  @override
  Future<void> change({
    required String operationId,
    required TrainerAssignment assignment,
    required DateTime date,
    required String fingerprint,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  }) async {
    if (recipe != null) validateWorkoutDraft(recipe);
    await _rpc('change_trainer_assignment_reviewed', {
      'p_fingerprint': fingerprint,
      'p_operation_id': operationId,
      'p_id': assignment.id,
      'p_expected_revision': assignment.revision,
      'p_date': trainerCalendarDate(date),
      'p_note': note,
      'p_recipe': recipe == null ? null : workoutDraftToJson(recipe),
    });
  }

  @override
  Future<TrainerAssignmentChangePreview> previewChange({
    required TrainerAssignment assignment,
    required DateTime date,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  }) async {
    if (recipe != null) validateWorkoutDraft(recipe);
    final data = WorkoutJson.from(
      await _rpc('preview_trainer_assignment_change', {
        'p_id': assignment.id,
        'p_expected_revision': assignment.revision,
        'p_date': trainerCalendarDate(date),
        'p_note': note,
        'p_recipe': recipe == null ? null : workoutDraftToJson(recipe),
      }) as Map,
    );
    return TrainerAssignmentChangePreview(
      fingerprint: data['fingerprint'] as String,
      hasDateCoincidence: data['has_date_coincidence'] as bool,
    );
  }

  @override
  Future<List<TrainerReviewItem>> reviews({TrainerReviewItem? before}) async =>
      (await _rpc('list_trainer_review_queue', {
            'p_before_at': before?.changedAt.toUtc().toIso8601String(),
            'p_before_id': before?.assignment.id,
          }) as List)
          .map(
            (row) => TrainerReviewItem.fromJson(WorkoutJson.from(row as Map)),
          )
          .toList();

  @override
  Future<void> markReviewed({
    required String operationId,
    required String assignmentId,
    required int resultRevision,
    String? privateNote,
  }) async {
    await _rpc('mark_trainer_assignment_reviewed', {
      'p_operation_id': operationId,
      'p_id': assignmentId,
      'p_seen_revision': resultRevision,
      'p_private_note': privateNote,
    });
  }
}
