import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RunningTestRepository {
  const RunningTestRepository(this.client);

  final SupabaseClient client;

  Future<List<RunningTestResult>> history(String goalId) async {
    final rows = await client
        .from('preparation_running_tests')
        .select(
          'completed_at,duration_seconds,rpe,average_hr_bpm,max_hr_bpm,notes,splits_seconds',
        )
        .eq('preparation_goal_id', goalId)
        .order('completed_at', ascending: false);
    return rows
        .map(
          (row) => RunningTestResult(
            completedAt: DateTime.parse(
              row['completed_at'] as String,
            ).toLocal(),
            durationSeconds: row['duration_seconds'] as int,
            rpe: row['rpe'] as int,
            averageHrBpm: row['average_hr_bpm'] as int?,
            maxHrBpm: row['max_hr_bpm'] as int?,
            notes: row['notes'] as String?,
            splitsSeconds: (row['splits_seconds'] as List<dynamic>?)
                ?.cast<int>(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> save(String goalId, RunningTestResult result) async {
    final error = result.validate();
    if (error != null) throw ArgumentError(error);
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para guardar el test.');
    await client.from('preparation_running_tests').insert({
      'user_id': userId,
      'preparation_goal_id': goalId,
      'protocol_version': 'run_2000m_v1',
      'completed_at': result.completedAt.toUtc().toIso8601String(),
      'duration_seconds': result.durationSeconds,
      'rpe': result.rpe,
      'average_hr_bpm': result.averageHrBpm,
      'max_hr_bpm': result.maxHrBpm,
      'notes': result.notes,
      'splits_seconds': result.splitsSeconds,
    });
  }
}
