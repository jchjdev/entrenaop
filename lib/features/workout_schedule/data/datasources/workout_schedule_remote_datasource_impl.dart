import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutScheduleRemoteDataSourceImpl
    implements WorkoutScheduleRemoteDataSource {
  const WorkoutScheduleRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<List<Map<String, dynamic>>> getRange(String start, String end) async {
    final response = await supabaseClient
        .from('scheduled_workouts')
        .select('''
          id,
          template_id,
          template_name,
          template_version,
          estimated_duration_minutes,
          preparation_goal_id,
          execution_id,
          scheduled_date,
          scheduled_time,
          source,
          status
        ''')
        .gte('scheduled_date', start)
        .lte('scheduled_date', end)
        .neq('status', 'cancelled')
        .order('scheduled_date')
        .order('scheduled_time')
        .order('order_index');
    return response.cast<Map<String, dynamic>>();
  }

  @override
  Future<String> schedule(
    String templateId,
    String date, {
    String? time,
    String? preparationGoalId,
  }) async {
    final response = await supabaseClient.rpc(
      'schedule_workout',
      params: {
        'p_template_id': templateId,
        'p_scheduled_date': date,
        'p_scheduled_time': time,
        'p_preparation_goal_id': preparationGoalId,
      },
    );
    return response as String;
  }

  @override
  Future<void> reschedule(String scheduledId, String date, {String? time}) =>
      supabaseClient.rpc(
        'reschedule_workout',
        params: {
          'p_scheduled_id': scheduledId,
          'p_scheduled_date': date,
          'p_scheduled_time': time,
        },
      );

  @override
  Future<void> cancel(String scheduledId) => supabaseClient.rpc(
    'cancel_scheduled_workout',
    params: {'p_scheduled_id': scheduledId},
  );

  @override
  Future<String> start(String scheduledId) async {
    final response = await supabaseClient.rpc(
      'start_scheduled_workout',
      params: {'p_scheduled_id': scheduledId},
    );
    return response as String;
  }
}
