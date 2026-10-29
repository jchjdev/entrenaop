import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

enum TrainerCatalogKind {
  session('sesión', '/workouts'),
  program('programa', '/programs'),
  exercise('ejercicio', '/exercises');

  const TrainerCatalogKind(this.label, this.libraryPath);
  final String label;
  final String libraryPath;
}

class TrainerCatalogTrashEntry {
  const TrainerCatalogTrashEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.trashedAt,
    this.revision,
    this.blockedReason,
  });
  TrainerCatalogTrashEntry.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      name = row['name'] as String,
      kind = TrainerCatalogKind.values.byName(row['kind'] as String),
      trashedAt = DateTime.parse(row['trashed_at'] as String),
      revision = row['revision'] as int?,
      blockedReason = row['delete_block_reason'] as String?;

  final String id, name;
  final TrainerCatalogKind kind;
  final DateTime trashedAt;
  final int? revision;
  final String? blockedReason;
}

abstract class TrainerCatalogTrashRepository {
  Object get ownerKey;
  Future<List<TrainerCatalogTrashEntry>> list(
    TrainerCatalogKind kind, {
    TrainerCatalogTrashEntry? before,
  });
  Future<void> trash(String operationId, TrainerCatalogKind kind, String id);
  Future<void> restore(String operationId, TrainerCatalogTrashEntry entry);
  Future<void> purge(String operationId, TrainerCatalogTrashEntry entry);
}

class SupabaseTrainerCatalogTrashRepository
    implements TrainerCatalogTrashRepository {
  SupabaseTrainerCatalogTrashRepository(
    this.client,
    this.userId, {
    this.cleanupAfterPurge,
  });
  final SupabaseClient client;
  final String userId;
  final Future<void> Function()? cleanupAfterPurge;

  @override
  Object get ownerKey => userId;

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    try {
      return await authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: params,
      );
    } on PostgrestException catch (error) {
      if (error.code == '40001') {
        throw const FormatException(
          'El contenido ha cambiado. Actualiza la papelera y vuelve a revisarlo.',
        );
      }
      if (['22023', 'P0001', '23503'].contains(error.code)) {
        throw FormatException(error.message);
      }
      if (error.code == '42501') {
        throw const FormatException(
          'No tienes permiso para esta operación. Comprueba tu acceso y el doble factor.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<TrainerCatalogTrashEntry>> list(
    TrainerCatalogKind kind, {
    TrainerCatalogTrashEntry? before,
  }) async {
    if (before != null && before.kind != kind) {
      throw const FormatException('El cursor no corresponde a este catálogo.');
    }
    final rows = await _rpc('list_trainer_catalog_trash', {
      'p_kind': kind.name,
      'p_before_at': before?.trashedAt.toUtc().toIso8601String(),
      'p_before_id': before?.id,
      'p_limit': 50,
    });
    final entries = (rows as List)
        .map(
          (row) => TrainerCatalogTrashEntry.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    if (entries.any((entry) => entry.kind != kind)) {
      throw const FormatException(
        'La papelera recibida no corresponde al catálogo.',
      );
    }
    return entries;
  }

  @override
  Future<void> trash(
    String operationId,
    TrainerCatalogKind kind,
    String id,
  ) async {
    final receipt = await _rpc('trash_trainer_catalog_item', {
      'p_operation_id': operationId,
      'p_kind': kind.name,
      'p_id': id,
    });
    // Una familia ya retirada puede devolver su representante original.
    _verifyReceipt(receipt, kind: kind, status: 'trashed');
  }

  Future<void> _change(
    String rpc,
    String operationId,
    TrainerCatalogTrashEntry entry,
  ) async {
    final receipt = await _rpc(rpc, {
      'p_operation_id': operationId,
      'p_kind': entry.kind.name,
      'p_id': entry.id,
      // El sello identifica esta entrada de papelera, nunca una retirada posterior.
      'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
    });
    _verifyReceipt(
      receipt,
      kind: entry.kind,
      status: rpc.startsWith('restore_') ? 'restored' : 'purged',
      id: entry.id,
    );
  }

  void _verifyReceipt(
    dynamic receipt, {
    required TrainerCatalogKind kind,
    required String status,
    String? id,
  }) {
    final valid =
        receipt is Map &&
        receipt['kind'] == kind.name &&
        receipt['status'] == status &&
        receipt['id'] is String &&
        (receipt['id'] as String).isNotEmpty &&
        (id == null || receipt['id'] == id) &&
        (status != 'trashed' ||
            (receipt['trashed_at'] is String &&
                DateTime.tryParse(receipt['trashed_at'] as String) != null));
    if (!valid) {
      // No sabemos si llegó a aplicarse: la UI conserva el UUID para consultar
      // de nuevo el mismo recibo, en lugar de dar por terminada otra operación.
      throw StateError(
        'No se ha recibido una confirmación válida. Reintenta la misma operación.',
      );
    }
  }

  @override
  Future<void> restore(String operationId, TrainerCatalogTrashEntry entry) =>
      _change('restore_trainer_catalog_item', operationId, entry);

  @override
  Future<void> purge(String operationId, TrainerCatalogTrashEntry entry) async {
    await _change('purge_trainer_catalog_item', operationId, entry);
    try {
      await cleanupAfterPurge?.call().timeout(const Duration(seconds: 5));
    } catch (_) {
      // La purga ya terminó. La cola reintentará el trabajo externo por Cron.
    }
  }
}
