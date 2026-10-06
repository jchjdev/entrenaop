import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RunningReferenceSelectionRepository {
  const RunningReferenceSelectionRepository(this._client);

  final SupabaseClient _client;

  Future<RunningReferenceSelection?> get(String goalId) async {
    final row = await _client
        .from('running_reference_selections')
        .select()
        .eq('preparation_goal_id', goalId)
        .maybeSingle();
    if (row == null) return null;
    return RunningReferenceSelection(
      goalId: goalId,
      source: RunningReferenceSource.values.byName(
        row['reference_source'] as String,
      ),
      recordId: row['reference_record_id'] as String,
      selectedAt: DateTime.parse(row['selected_at'] as String).toLocal(),
      continuityConfirmedAt: row['continuity_confirmed_at'] == null
          ? null
          : DateTime.parse(row['continuity_confirmed_at'] as String).toLocal(),
    );
  }

  Future<void> save(RunningReferenceSelection selection) async {
    await _client.from('running_reference_selections').upsert({
      'preparation_goal_id': selection.goalId,
      'reference_source': selection.source.name,
      'reference_record_id': selection.recordId,
      'selected_at': selection.selectedAt.toUtc().toIso8601String(),
      'continuity_confirmed_at': selection.continuityConfirmedAt
          ?.toUtc()
          .toIso8601String(),
    });
  }

  Future<void> clear(String goalId) async {
    await _client
        .from('running_reference_selections')
        .delete()
        .eq('preparation_goal_id', goalId);
  }
}
