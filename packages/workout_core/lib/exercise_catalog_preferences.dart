/// Preferencias de autoría. No son permisos ni historial de entrenamiento.
enum ExercisePreferenceContext { adminOfficial, trainerPrivate }

class ExercisePreferenceEntry {
  const ExercisePreferenceEntry({
    required this.exerciseId,
    required this.favorite,
    required this.favoriteRevision,
    this.lastSelectedAt,
  });

  final String exerciseId;
  final bool favorite;
  final int favoriteRevision;
  final DateTime? lastSelectedAt;
}

class ExercisePreferenceSnapshot {
  ExercisePreferenceSnapshot({
    required Iterable<ExercisePreferenceEntry> entries,
    this.recentLimit = 20,
    this.favoriteLimit = 500,
  }) : entries = List.unmodifiable(entries);

  final List<ExercisePreferenceEntry> entries;
  final int recentLimit, favoriteLimit;
}

/// El adaptador puede aportar la revisión vigente para resolver un conflicto.
class ExercisePreferenceConflict implements Exception {
  const ExercisePreferenceConflict(this.current);
  final ExercisePreferenceEntry current;
}

/// Instancia ligada a cuenta, proyecto y contexto por el consumidor.
/// Los operationId se conservan al reintentar una respuesta incierta.
abstract interface class ExerciseCatalogPreferences {
  String newOperationId();
  Future<ExercisePreferenceSnapshot> read();
  Future<ExercisePreferenceEntry> setFavorite(
    String exerciseId,
    bool favorite, {
    required int expectedRevision,
    required String operationId,
  });
  Future<ExercisePreferenceEntry> recordSelection(
    String exerciseId, {
    required String operationId,
  });
}
