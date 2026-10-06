import 'package:supabase_flutter/supabase_flutter.dart';

/// Solo el servidor decide y publica. El cliente presenta la decisión devuelta.
class RunningWeekPlanRepository {
  const RunningWeekPlanRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> calculate(String goalId, DateTime monday) =>
      _call('calculate_running_week', goalId, monday);

  Future<Map<String, dynamic>> previewInitialWithCurrentPolicy(
    String goalId,
    DateTime monday,
  ) => _call('preview_running_initial_week', goalId, monday);

  Future<Map<String, dynamic>> previewNextFromCompletedWeek(
    String goalId,
  ) async {
    final result = await _client.rpc(
      'preview_running_next_week',
      params: {'p_goal_id': goalId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> publish(String goalId, DateTime monday) =>
      _call('publish_running_week', goalId, monday);

  Future<int> publishedWeeks(String goalId) async {
    final rows = await _client
        .from('running_week_decisions')
        .select('id')
        .eq('preparation_goal_id', goalId)
        .isFilter('superseded_at', null);
    return rows.length;
  }

  Future<Map<String, dynamic>> reset(String goalId) async {
    final result = await _client.rpc(
      'reset_running_plan',
      params: {'p_goal_id': goalId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> _call(
    String function,
    String goalId,
    DateTime monday,
  ) async {
    final date =
        '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
    final result = await _client.rpc(
      function,
      params: {'p_goal_id': goalId, 'p_week_start': date},
    );
    return Map<String, dynamic>.from(result as Map);
  }
}
