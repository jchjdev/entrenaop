import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

class SupabaseAdminWorkoutWorkRepository
    implements WorkoutEditorWorkRepository {
  const SupabaseAdminWorkoutWorkRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> params) =>
      authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: {...params, 'p_expected_owner': userId},
      );
  WorkoutEditorWork _decode(dynamic value) {
    final row = Map<String, dynamic>.from(value as Map);
    return WorkoutEditorWork(
      id: row['id'] as String,
      origin: Map<String, dynamic>.from(row['origin'] as Map),
      state: Map<String, dynamic>.from(row['state'] as Map),
      revision: (row['revision'] as num).toInt(),
      resultId: row['result_id'] as String?,
      discarded: row['discarded'] == true,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  @override
  Future<List<WorkoutEditorWork>> list() async =>
      (await _rpc('list_admin_session_work', {}) as List).map(_decode).toList();
  @override
  Future<WorkoutEditorWork?> load(String id) async {
    final row = await _rpc('get_admin_session_work', {'p_id': id});
    return row == null ? null : _decode(row);
  }

  @override
  Future<WorkoutEditorWork> save(
    WorkoutEditorWork work,
    Map<String, dynamic> state,
  ) async {
    try {
      return _decode(
        await _rpc('save_admin_session_work', {
          'p_id': work.id,
          'p_revision': work.revision,
          'p_origin': work.origin,
          'p_state': state,
        }),
      );
    } on PostgrestException catch (e) {
      if (e.code == '40001') throw const WorkoutWorkConflict();
      rethrow;
    }
  }

  @override
  Future<String> finalize(WorkoutEditorWork work) async => await _rpc(
    'finalize_admin_session_work',
    {'p_id': work.id, 'p_revision': work.revision},
  ) as String;
  @override
  Future<void> discard(WorkoutEditorWork work) async {
    await _rpc('discard_admin_session_work', {
      'p_id': work.id,
      'p_revision': work.revision,
    });
  }

  @override
  Future<WorkoutEditorWork> reopen(WorkoutEditorWork work) async => _decode(
    await _rpc('reopen_admin_session_work', {
      'p_id': work.id,
      'p_revision': work.revision,
    }),
  );
}
