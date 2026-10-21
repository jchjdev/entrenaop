import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_guided_trash.dart';

class SupabaseAdminGuidedTrashRepository implements AdminGuidedTrashRepository {
  const SupabaseAdminGuidedTrashRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<GuidedTrashEntry>> list() async =>
      (await client.rpc('list_admin_guided_program_trash') as List)
          .map(
            (row) => GuidedTrashEntry.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.trashedAt.compareTo(a.trashedAt));

  @override
  Future<void> trashProgram(String programId) async {
    await client.rpc(
      'trash_admin_guided_program',
      params: {'p_program_id': programId},
    );
  }

  @override
  Future<void> restore(GuidedTrashEntry entry) async {
    await client.rpc(
      entry.isWork
          ? 'restore_admin_guided_work'
          : 'restore_admin_guided_program',
      params: entry.isWork
          ? {'p_id': entry.id, 'p_revision': entry.revision}
          : {
              'p_family_id': entry.id,
              'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
            },
    );
  }
}
