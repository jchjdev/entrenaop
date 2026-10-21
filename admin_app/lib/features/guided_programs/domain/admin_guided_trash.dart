class GuidedTrashEntry {
  const GuidedTrashEntry({
    required this.id,
    required this.name,
    required this.isWork,
    required this.trashedAt,
    this.isSession = false,
    this.revision,
    this.versions = 0,
    this.workCount = 0,
  });

  final String id, name;
  final bool isWork, isSession;
  final DateTime trashedAt;
  final int? revision;
  final int versions, workCount;

  factory GuidedTrashEntry.fromJson(Map<String, dynamic> row) =>
      GuidedTrashEntry(
        id: row['id'] as String,
        name: row['name'] as String,
        isWork: row['kind'] == 'work',
        isSession: row['kind'] == 'session',
        trashedAt: DateTime.parse(row['trashed_at'] as String),
        revision: (row['revision'] as num?)?.toInt(),
        versions: (row['versions'] as num).toInt(),
        workCount: (row['work_count'] as num).toInt(),
      );
}

abstract interface class AdminGuidedTrashRepository {
  Future<List<GuidedTrashEntry>> list();
  Future<List<GuidedTrashEntry>> listSessions();
  Future<void> trashProgram(String programId);
  Future<void> trashSession(String sessionId);
  Future<void> restore(GuidedTrashEntry entry);
  Future<void> deletePermanently(GuidedTrashEntry entry);
}
