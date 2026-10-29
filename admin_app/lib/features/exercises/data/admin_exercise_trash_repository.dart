class AdminExerciseTrashEntry {
  const AdminExerciseTrashEntry({
    required this.id,
    required this.name,
    required this.trashedAt,
    this.deleteBlockReason,
  });

  final String id, name;
  final DateTime trashedAt;
  final String? deleteBlockReason;

  factory AdminExerciseTrashEntry.fromJson(Map<String, dynamic> row) =>
      AdminExerciseTrashEntry(
        id: row['id'] as String,
        name: row['name'] as String,
        trashedAt: DateTime.parse(row['trashed_at'] as String),
        deleteBlockReason: row['delete_block_reason'] as String?,
      );
}

/// Capacidad separada para no convertir catálogos de solo lectura en autores.
abstract interface class AdminExerciseTrashRepository {
  Future<List<AdminExerciseTrashEntry>> listExerciseTrash({
    AdminExerciseTrashEntry? before,
    int limit = 50,
  });
  Future<void> trashExercise(String id, {required String operationId});
  Future<void> restoreExercise(
    AdminExerciseTrashEntry entry, {
    required String operationId,
  });
  Future<void> purgeExercise(
    AdminExerciseTrashEntry entry, {
    required String operationId,
  });
}
