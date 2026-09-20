import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
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
    workout_execution_sets (
      id,
      block_order,
      block_name,
      item_order,
      exercise_id,
      exercise_name,
      set_order,
      target_reps,
      target_duration_seconds,
      target_distance_meters,
      target_load_kg,
      target_rpe,
      target_rir,
      rest_after_seconds,
      status,
      actual_reps,
      actual_duration_seconds,
      actual_distance_meters,
      actual_load_kg,
      actual_rpe,
      actual_rir
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
  Future<void> completeSet(Map<String, dynamic> values) =>
      supabaseClient.rpc('complete_workout_set', params: values);

  @override
  Future<void> skipSet(String resultId) =>
      supabaseClient.rpc('skip_workout_set', params: {'p_result_id': resultId});

  @override
  Future<void> finishExecution(String executionId, int finalRpe) =>
      supabaseClient.rpc(
        'finish_workout_execution',
        params: {'p_execution_id': executionId, 'p_final_rpe': finalRpe},
      );

  @override
  Future<void> abandonExecution(String executionId, String reason) =>
      supabaseClient.rpc(
        'abandon_workout_execution',
        params: {'p_execution_id': executionId, 'p_reason': reason},
      );
}
