import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/data/models/workout_execution_model.dart';
import 'package:entrenaop/features/workouts/data/models/workout_template_model.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_mutation_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({
    required this.remoteDataSource,
    required this.mutationQueue,
    this.uuid = const Uuid(),
  });

  final WorkoutRemoteDataSource remoteDataSource;
  final WorkoutMutationQueue mutationQueue;
  final Uuid uuid;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async {
    final json = await remoteDataSource.getTemplateById(id);
    return json == null ? null : WorkoutTemplateModel.fromJson(json);
  }

  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async {
    final rows = await remoteDataSource.getPublicTemplates();
    return rows
        .map(WorkoutTemplateSummaryModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async {
    final rows = await remoteDataSource.getPersonalTemplates();
    return rows
        .map(WorkoutTemplateSummaryModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<String> createPersonalTemplate(CreatePersonalWorkoutInput input) {
    return remoteDataSource.createPersonalTemplate(_draftToJson(input));
  }

  @override
  Future<String> duplicatePersonalTemplate(String templateId) =>
      remoteDataSource.duplicatePersonalTemplate(templateId);

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) => remoteDataSource.revisePersonalTemplate(templateId, _draftToJson(input));

  @override
  Future<void> archivePersonalTemplate(String templateId) =>
      remoteDataSource.archivePersonalTemplate(templateId);

  @override
  Future<String> startExecution(String templateId) =>
      remoteDataSource.startExecution(templateId);

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async {
    await _trySyncPending();
    final json = await remoteDataSource.getExecution(executionId);
    return json == null ? null : WorkoutExecutionModel.fromJson(json);
  }

  @override
  Future<List<WorkoutExecution>> getExecutionHistory() async {
    await _trySyncPending();
    final rows = await remoteDataSource.getExecutionHistory();
    return rows.map(WorkoutExecutionModel.fromJson).toList(growable: false);
  }

  @override
  Future<WorkoutMutationDisposition> completeSet(WorkoutSetResultInput result) {
    final values = <String, dynamic>{
      'p_result_id': result.resultId,
      'p_actual_reps': result.actualReps,
      'p_actual_duration_seconds': result.actualDurationSeconds,
      'p_actual_distance_meters': result.actualDistanceMeters,
      'p_actual_load_kg': result.actualLoadKg,
      'p_actual_rpe': result.actualRpe,
      'p_actual_rir': result.actualRir,
    };
    final mutation = _mutation(
      WorkoutMutationType.completeSet,
      result.resultId,
      values,
    );
    return _performOrQueue(
      mutation,
      () => remoteDataSource.completeSet(mutation.operationId, values),
    );
  }

  @override
  Future<WorkoutMutationDisposition> completeAmrap(
    WorkoutAmrapResultInput result,
  ) {
    final values = <String, dynamic>{
      'p_execution_id': result.executionId,
      'p_block_order': result.blockOrder,
      'p_completed_rounds': result.completedRounds,
      'p_partial_item_order': result.partialItemOrder,
      'p_partial_reps': result.partialReps,
    };
    final mutation = _mutation(
      WorkoutMutationType.completeAmrap,
      result.executionId,
      values,
    );
    return _performOrQueue(
      mutation,
      () => remoteDataSource.completeAmrap(mutation.operationId, values),
    );
  }

  @override
  Future<void> correctSet(WorkoutSetCorrectionInput correction) {
    return remoteDataSource.correctSet({
      'p_result_id': correction.resultId,
      'p_reason': correction.reason,
      'p_actual_reps': correction.actualReps,
      'p_actual_duration_seconds': correction.actualDurationSeconds,
      'p_actual_distance_meters': correction.actualDistanceMeters,
      'p_actual_load_kg': correction.actualLoadKg,
      'p_actual_rpe': correction.actualRpe,
      'p_actual_rir': correction.actualRir,
    });
  }

  @override
  Future<WorkoutMutationDisposition> skipSet(String resultId) {
    final mutation = _mutation(WorkoutMutationType.skipSet, resultId, const {});
    return _performOrQueue(
      mutation,
      () => remoteDataSource.skipSet(mutation.operationId, resultId),
    );
  }

  @override
  Future<WorkoutMutationDisposition> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
  }) {
    final values = <String, dynamic>{'p_final_rpe': finalRpe, 'p_notes': notes};
    final mutation = _mutation(WorkoutMutationType.finish, executionId, values);
    return _performOrQueue(
      mutation,
      () => remoteDataSource.finishExecution(
        mutation.operationId,
        executionId,
        finalRpe: finalRpe,
        notes: notes,
      ),
    );
  }

  @override
  Future<WorkoutMutationDisposition> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) {
    final reasonValue = _reasonValue(reason);
    final mutation = _mutation(WorkoutMutationType.abandon, executionId, {
      'p_reason': reasonValue,
    });
    return _performOrQueue(
      mutation,
      () => remoteDataSource.abandonExecution(
        mutation.operationId,
        executionId,
        reasonValue,
      ),
    );
  }

  @override
  Future<int> getPendingMutationCount() async =>
      (await mutationQueue.readAll()).length;

  @override
  Future<void> syncPendingMutations() async {
    final pending = await mutationQueue.readAll();
    for (final mutation in pending) {
      await _sendPending(mutation);
      await mutationQueue.remove(mutation.operationId);
    }
  }

  PendingWorkoutMutation _mutation(
    WorkoutMutationType type,
    String resourceId,
    Map<String, dynamic> values,
  ) => PendingWorkoutMutation(
    operationId: uuid.v4(),
    type: type,
    resourceId: resourceId,
    values: values,
    createdAt: DateTime.now().toUtc(),
  );

  Future<WorkoutMutationDisposition> _performOrQueue(
    PendingWorkoutMutation mutation,
    Future<void> Function() send,
  ) async {
    try {
      await send();
      return WorkoutMutationDisposition.synced;
    } on PostgrestException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (_) {
      await mutationQueue.enqueue(mutation);
      return WorkoutMutationDisposition.queued;
    }
  }

  Future<void> _trySyncPending() async {
    try {
      await syncPendingMutations();
    } catch (_) {
      // La lectura todavía puede ser útil aunque la conexión siga inestable.
    }
  }

  Future<void> _sendPending(PendingWorkoutMutation mutation) =>
      switch (mutation.type) {
        WorkoutMutationType.completeSet => remoteDataSource.completeSet(
          mutation.operationId,
          mutation.values,
        ),
        WorkoutMutationType.completeAmrap => remoteDataSource.completeAmrap(
          mutation.operationId,
          mutation.values,
        ),
        WorkoutMutationType.skipSet => remoteDataSource.skipSet(
          mutation.operationId,
          mutation.resourceId,
        ),
        WorkoutMutationType.finish => remoteDataSource.finishExecution(
          mutation.operationId,
          mutation.resourceId,
          finalRpe: mutation.values['p_final_rpe'] as int,
          notes: mutation.values['p_notes'] as String?,
        ),
        WorkoutMutationType.abandon => remoteDataSource.abandonExecution(
          mutation.operationId,
          mutation.resourceId,
          mutation.values['p_reason'] as String,
        ),
      };
}

Map<String, dynamic> _draftToJson(CreatePersonalWorkoutInput input) => {
  'name': input.name.trim(),
  'description': input.description?.trim(),
  'estimated_duration_minutes': input.estimatedDurationMinutes,
  'blocks': input.blocks
      .map(
        (block) => {
          'name': block.name.trim(),
          'format': _blockFormatValue(block.format),
          'rounds': block.rounds,
          if (block.timeCapSeconds != null)
            'time_cap_seconds': block.timeCapSeconds,
          'rest_after_seconds': block.restAfterSeconds,
          'exercises': block.exercises
              .map(
                (exercise) => {
                  'exercise_id': exercise.exerciseId,
                  'sets': exercise.sets.map(_setDraftToJson).toList(),
                },
              )
              .toList(),
        },
      )
      .toList(),
};

String _blockFormatValue(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.straightSets => 'straight_sets',
  WorkoutBlockFormat.circuit => 'circuit',
  WorkoutBlockFormat.superset => 'superset',
  WorkoutBlockFormat.intervals => 'intervals',
  WorkoutBlockFormat.emom => 'emom',
  WorkoutBlockFormat.amrap => 'amrap',
  WorkoutBlockFormat.tabata => 'tabata',
  WorkoutBlockFormat.warmUp => 'warm_up',
  WorkoutBlockFormat.coolDown => 'cool_down',
};

Map<String, dynamic> _setDraftToJson(WorkoutSetDraft set) => {
  'target_reps': set.targetType == WorkoutTargetType.repetitions
      ? set.targetValue.round()
      : null,
  'target_duration_seconds': set.targetType == WorkoutTargetType.duration
      ? set.targetValue.round()
      : null,
  'target_distance_meters': set.targetType == WorkoutTargetType.distance
      ? set.targetValue
      : null,
  'target_load_kg': set.targetLoadKg,
  'target_rir': set.targetRir,
  'rest_after_seconds': set.restAfterSeconds,
};

String _reasonValue(WorkoutAbandonmentReason reason) => switch (reason) {
  WorkoutAbandonmentReason.lackOfTime => 'lack_of_time',
  WorkoutAbandonmentReason.tooDifficult => 'too_difficult',
  WorkoutAbandonmentReason.discomfort => 'discomfort',
  WorkoutAbandonmentReason.other => 'other',
};
