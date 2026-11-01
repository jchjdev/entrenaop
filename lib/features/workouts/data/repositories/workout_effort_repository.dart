import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../../domain/usecases/record_workout_effort.dart';

class SupabaseWorkoutEffortRepository implements WorkoutEffortRepository {
  SupabaseWorkoutEffortRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;

  @override
  Future<void> record(String executionId, int rpe) async {
    // Este transporte común fija el JWT de la cuenta. Los permisos de la RPC
    // son personales: no exigen ni conceden acceso profesional.
    await authenticatedTrainerRpc(
      client,
      owner,
      'add_device_workout_effort',
      params: {
        'p_expected_owner': owner,
        'p_execution_id': executionId,
        'p_rpe': rpe,
      },
    );
  }
}
