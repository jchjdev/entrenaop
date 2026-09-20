import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutRemoteDataSourceImpl implements WorkoutRemoteDataSource {
  const WorkoutRemoteDataSourceImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

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
}
