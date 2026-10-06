import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recupera datos v1 únicamente cuando el servidor acredita su propietario.
class WorkoutLegacyMutationOwner {
  const WorkoutLegacyMutationOwner(this._client);

  final SupabaseClient _client;

  Future<bool> owns(PendingWorkoutMutation mutation, String userId) async {
    if (_client.auth.currentUser?.id != userId) return false;
    if (mutation.type == WorkoutMutationType.completeSet &&
        mutation.values['p_result_id'] != mutation.resourceId) {
      return false;
    }
    if (mutation.type == WorkoutMutationType.completeAmrap &&
        mutation.values['p_execution_id'] != mutation.resourceId) {
      return false;
    }
    final Map<String, dynamic>? row;
    switch (mutation.type) {
      case WorkoutMutationType.completeSet:
      case WorkoutMutationType.skipSet:
        row = await _client
            .from('workout_execution_sets')
            .select('id, workout_executions!inner(user_id)')
            .eq('id', mutation.resourceId)
            .eq('workout_executions.user_id', userId)
            .maybeSingle();
      case WorkoutMutationType.completeAmrap:
      case WorkoutMutationType.finish:
      case WorkoutMutationType.abandon:
        row = await _client
            .from('workout_executions')
            .select('id')
            .eq('id', mutation.resourceId)
            .eq('user_id', userId)
            .maybeSingle();
    }
    return row != null && _client.auth.currentUser?.id == userId;
  }
}
