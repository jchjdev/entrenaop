import 'package:entrenaop/features/workout_schedule/data/datasources/workout_schedule_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../../../../core/config/app_config.dart';

class WorkoutScheduleRemoteDataSourceImpl
    implements WorkoutScheduleRemoteDataSource {
  const WorkoutScheduleRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<List<Map<String, dynamic>>> getRange(String start, String end) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return const [];
    // Corrige únicamente vínculos manuales creados antes de cerrar la frontera
    // de los planes oficiales. La función está acotada al usuario autenticado.
    await supabaseClient.rpc('cleanup_own_legacy_preparation_links');
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
          status,
          trainer_assignments(note)
        ''')
        .eq('user_id', userId)
        .gte('scheduled_date', start)
        .lte('scheduled_date', end)
        .neq('status', 'cancelled')
        .order('scheduled_date')
        .order('scheduled_time')
        .order('order_index');
    if (supabaseClient.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    final rows = response.cast<Map<String, dynamic>>();
    final ids = rows
        .where((r) => r['source'] == 'coach')
        .map((r) => r['id'] as String)
        .toList();
    final names = <String, String>{};
    final selfAssigned = <String>{};
    for (var start = 0; start < ids.length; start += 200) {
      final end = (start + 200).clamp(0, ids.length);
      final value = await authenticatedTrainerRpc(
        supabaseClient,
        userId,
        'get_my_schedule_coaches',
        params: {'p_expected_owner': userId, 'p_ids': ids.sublist(start, end)},
      ) as List;
      for (final item in value.cast<Map>()) {
        names[item['id'] as String] = item['trainer_name'] as String;
        if (item['is_self'] == true) selfAssigned.add(item['id'] as String);
      }
    }
    final apple = <String, dynamic>{};
    if (AppConfig.environment == AppEnvironment.development) {
      final allIds = rows.map((r) => r['id'] as String).toList();
      for (var i = 0; i < allIds.length; i += 200) {
        final value = await authenticatedTrainerRpc(
          supabaseClient,
          userId,
          'my_apple_workout_results',
          params: {
            'p_owner': userId,
            'p_ids': allIds.sublist(i, (i + 200).clamp(0, allIds.length)),
          },
        );
        apple.addAll(Map<String, dynamic>.from(value as Map));
      }
    }
    if (supabaseClient.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    return rows
        .map(
          (r) => {
            ...r,
            'trainer_name': ?names[r['id']],
            'is_self': selfAssigned.contains(r['id']),
            'apple_results': apple[r['id']] ?? const [],
          },
        )
        .toList();
  }

  @override
  Future<String> schedule(
    String templateId,
    String date, {
    String? time,
  }) async {
    final response = await supabaseClient.rpc(
      'schedule_workout',
      params: {
        'p_template_id': templateId,
        'p_scheduled_date': date,
        'p_scheduled_time': time,
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
