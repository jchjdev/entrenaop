import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';

import '../domain/admin_guided_work.dart';

class SupabaseAdminGuidedWorkRepository implements AdminGuidedWorkRepository {
  const SupabaseAdminGuidedWorkRepository(this.client);
  final SupabaseClient client;
  GuidedWork _decode(Map<String, dynamic> row) => GuidedWork(
    id: row['id'] as String,
    state: Map<String, dynamic>.from(row['state'] as Map),
    revision: (row['revision'] as num).toInt(),
    baseProgramId: row['base_program_id'] as String?,
    finalizedProgramId: row['finalized_program_id'] as String?,
    updatedAt: DateTime.parse(row['updated_at'] as String),
    discarded:
        row['discarded_at'] != null ||
        (row['base_program'] as Map?)?['trashed_at'] != null,
  );
  // El servidor verifica administrador y propiedad; no se confía en un filtro Flutter.
  @override
  Future<List<GuidedWork>> list() async =>
      (await client
              .from('admin_guided_work_drafts')
              .select(
                'id,state,revision,base_program_id,finalized_program_id,updated_at,discarded_at,base_program:guided_programs!admin_guided_work_drafts_base_program_id_fkey(trashed_at)',
              )
              .isFilter('finalized_program_id', null)
              .isFilter('discarded_at', null)
              .order('updated_at', ascending: false))
          .map(_decode)
          .where((work) => !work.discarded)
          .toList();
  @override
  Future<GuidedWork?> load(String id) async {
    final row = await client
        .from('admin_guided_work_drafts')
        .select(
          'id,state,revision,base_program_id,finalized_program_id,updated_at,discarded_at,base_program:guided_programs!admin_guided_work_drafts_base_program_id_fkey(trashed_at)',
        )
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _decode(row);
  }

  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    try {
      return _decode(
        Map<String, dynamic>.from(
          await client.rpc(
            'save_admin_guided_work',
            params: {
              'p_id': work.id,
              'p_revision': work.revision,
              'p_state': state,
              'p_base_program_id': work.baseProgramId,
            },
          ) as Map,
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '40001') throw const GuidedWorkConflict();
      rethrow;
    }
  }

  @override
  Future<String> finalize(GuidedWork work, GuidedProgram program) async =>
      (await client.rpc(
        'finalize_admin_guided_work',
        params: {
          'p_id': work.id,
          'p_revision': work.revision,
          'p_content': guidedProgramToJson(program),
          'p_category_ids': program.categories.map((c) => c.id).toList(),
          'p_primary_category_id': program.primaryCategoryId,
        },
      )) as String;
  @override
  Future<void> discard(GuidedWork work) async {
    await client.rpc(
      'discard_admin_guided_work',
      params: {'p_id': work.id, 'p_revision': work.revision},
    );
  }
}
