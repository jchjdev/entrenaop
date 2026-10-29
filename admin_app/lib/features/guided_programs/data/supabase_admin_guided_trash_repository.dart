import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../domain/admin_guided_trash.dart';

class SupabaseAdminGuidedTrashRepository implements AdminGuidedTrashRepository {
  const SupabaseAdminGuidedTrashRepository(this.client, {this.ownerId});
  final SupabaseClient client;
  final String? ownerId;

  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) {
    final expectedOwner = ownerId ?? client.auth.currentUser?.id;
    if (expectedOwner == null) throw StateError('Se necesita una sesión válida.');
    return authenticatedTrainerRpc(client, expectedOwner, name, params: params);
  }

  @override
  Future<List<GuidedTrashEntry>> list() =>
      _list('list_admin_guided_program_trash');

  @override
  Future<List<GuidedTrashEntry>> listSessions() =>
      _list('list_admin_session_trash');

  Future<List<GuidedTrashEntry>> _list(String rpc) async =>
      (await _rpc(rpc) as List)
          .map(
            (row) => GuidedTrashEntry.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.trashedAt.compareTo(a.trashedAt));

  @override
  Future<void> trashProgram(String programId) async {
    await _rpc(
      'trash_admin_guided_program',
      params: {'p_program_id': programId},
    );
  }

  Future<void> _mutate(String rpc, Map<String, dynamic> params) async {
    try {
      await _rpc(rpc, params: params);
    } on PostgrestException catch (error) {
      // Solo los rechazos de negocio definidos por nuestras RPC son mostrables.
      if (error.code == 'P0001' || error.code == '22023') {
        throw FormatException(error.message);
      }
      if (error.code == '40001') {
        throw const FormatException(
          'La papelera ha cambiado. Actualiza antes de reintentar.',
        );
      }
      if (error.code == '42501' || error.code == '28000') {
        throw const FormatException(
          'La cuenta no tiene permiso para completar esta operación. Comprueba el acceso y el doble factor.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> trashSession(String sessionId) =>
      _mutate('trash_admin_session', {'p_id': sessionId});

  @override
  Future<void> deletePermanently(GuidedTrashEntry entry) =>
      _mutate('purge_admin_trash', {
        'p_kind': entry.isSession
            ? 'session'
            : entry.isWork
            ? 'work'
            : 'program',
        'p_id': entry.id,
        'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
        'p_revision': entry.revision,
      });

  @override
  Future<void> restore(GuidedTrashEntry entry) async {
    await _mutate(
      entry.isSession
          ? 'restore_admin_session'
          : entry.isWork
          ? 'restore_admin_guided_work'
          : 'restore_admin_guided_program',
      entry.isSession
          ? {
              'p_id': entry.id,
              'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
            }
          : entry.isWork
          ? {'p_id': entry.id, 'p_revision': entry.revision}
          : {
              'p_family_id': entry.id,
              'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
            },
    );
  }
}
