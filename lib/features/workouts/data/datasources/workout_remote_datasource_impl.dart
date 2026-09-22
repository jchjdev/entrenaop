import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRemoteDataSourceImpl implements WorkoutRemoteDataSource {
  const WorkoutRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  static const _executionSelect = '''
    id,
    template_id,
    template_name,
    template_version,
    status,
    started_at,
    completed_at,
    final_rpe,
    notes,
    abandonment_reason,
    average_heart_rate_bpm,
    max_heart_rate_bpm,
    result_source,
    workout_amrap_results (
      block_order,
      completed_rounds,
      partial_item_order,
      partial_reps,
      completed_at
    ),
    workout_execution_sets (
      id,
      block_order,
      block_name,
      block_format,
      block_time_cap_seconds,
      item_order,
      exercise_id,
      exercise_name,
      exercise_description,
      exercise_video_url,
      set_order,
      target_reps,
      target_duration_seconds,
      target_distance_meters,
      target_load_kg,
      target_rpe,
      target_rir,
      target_pace_min_seconds_per_km,
      target_pace_max_seconds_per_km,
      recovery_type,
      recovery_duration_seconds,
      recovery_distance_meters,
      rest_after_seconds,
      status,
      actual_reps,
      actual_duration_seconds,
      actual_distance_meters,
      actual_load_kg,
      actual_rpe,
      actual_rir,
      actual_recovery_duration_seconds,
      actual_recovery_distance_meters,
      result_source,
      completed_at
    )
  ''';

  @override
  Future<Map<String, dynamic>?> getTemplateById(String id) async {
    final response = await supabaseClient
        .from('workout_templates')
        .select('''
          id,
          name,
          description,
          estimated_duration_minutes,
          version,
          workout_blocks (
            id,
            order_index,
            name,
            format,
            rounds,
            time_cap_seconds,
            rest_after_seconds,
            workout_items (
              id,
              order_index,
              notes,
              exercises (id, name, description),
              workout_sets (
                id,
                order_index,
                target_reps,
                target_duration_seconds,
                target_distance_meters,
                target_load_kg,
                target_rpe,
                target_rir,
                target_pace_min_seconds_per_km,
                target_pace_max_seconds_per_km,
                recovery_type,
                recovery_duration_seconds,
                recovery_distance_meters,
                rest_after_seconds
              )
            )
          )
        ''')
        .eq('id', id)
        .maybeSingle();

    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> getPublicTemplates() async {
    final response = await supabaseClient
        .from('workout_templates')
        .select(
          'id, name, description, estimated_duration_minutes, origin, version, workout_blocks(format)',
        )
        .eq('visibility', 'public')
        .eq('status', 'published')
        .order('created_at');
    return response.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> getPersonalTemplates() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await supabaseClient
        .from('workout_templates')
        .select(
          'id, name, description, estimated_duration_minutes, origin, version, workout_blocks(format)',
        )
        .eq('owner_user_id', userId)
        .eq('origin', 'user')
        .neq('status', 'archived')
        .order('updated_at', ascending: false);
    return response.cast<Map<String, dynamic>>();
  }

  @override
  Future<String> createPersonalTemplate(Map<String, dynamic> payload) async {
    final response = await supabaseClient.rpc(
      'create_personal_workout_template',
      params: {'p_payload': payload},
    );
    return response as String;
  }

  @override
  Future<String> duplicatePersonalTemplate(String templateId) async {
    final response = await supabaseClient.rpc(
      'duplicate_personal_workout_template',
      params: {'p_template_id': templateId},
    );
    return response as String;
  }

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    Map<String, dynamic> payload,
  ) async {
    final response = await supabaseClient.rpc(
      'revise_personal_workout_template',
      params: {'p_template_id': templateId, 'p_payload': payload},
    );
    return response as String;
  }

  @override
  Future<void> archivePersonalTemplate(String templateId) => supabaseClient.rpc(
    'archive_personal_workout_template',
    params: {'p_template_id': templateId},
  );

  @override
  Future<String> startExecution(String templateId) async {
    final response = await supabaseClient.rpc(
      'start_workout_execution',
      params: {'p_template_id': templateId},
    );
    return response as String;
  }

  @override
  Future<Map<String, dynamic>?> getExecution(String executionId) async {
    return supabaseClient
        .from('workout_executions')
        .select(_executionSelect)
        .eq('id', executionId)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> getExecutionHistory() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return const [];
    final response = await supabaseClient
        .from('workout_executions')
        .select(_executionSelect)
        .eq('user_id', userId)
        .neq('status', 'in_progress')
        .order('started_at', ascending: false)
        .limit(30);
    return response.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> completeSet(String operationId, Map<String, dynamic> values) =>
      supabaseClient.rpc(
        'complete_workout_set_idempotent',
        params: {'p_operation_id': operationId, ...values},
      );

  @override
  Future<void> completeAmrap(String operationId, Map<String, dynamic> values) =>
      supabaseClient.rpc(
        'complete_amrap_block_idempotent',
        params: {...values, 'p_operation_id': operationId},
      );

  @override
  Future<void> correctSet(Map<String, dynamic> values) =>
      supabaseClient.rpc('correct_workout_set_result', params: values);

  @override
  Future<void> skipSet(String operationId, String resultId) =>
      supabaseClient.rpc(
        'skip_workout_set_idempotent',
        params: {'p_operation_id': operationId, 'p_result_id': resultId},
      );

  @override
  Future<void> finishExecution(
    String operationId,
    String executionId, {
    required int finalRpe,
    String? notes,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
    WorkoutResultSource resultSource = WorkoutResultSource.manual,
  }) => supabaseClient.rpc(
    'finish_workout_execution_idempotent',
    params: {
      'p_operation_id': operationId,
      'p_execution_id': executionId,
      'p_final_rpe': finalRpe,
      'p_notes': notes,
      'p_average_heart_rate_bpm': averageHeartRateBpm,
      'p_max_heart_rate_bpm': maxHeartRateBpm,
      'p_result_source': resultSource.name,
    },
  );

  @override
  Future<void> abandonExecution(
    String operationId,
    String executionId,
    String reason,
  ) => supabaseClient.rpc(
    'abandon_workout_execution_idempotent',
    params: {
      'p_operation_id': operationId,
      'p_execution_id': executionId,
      'p_reason': reason,
    },
  );
}
