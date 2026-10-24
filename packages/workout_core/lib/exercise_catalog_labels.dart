class ExerciseLabelEntry {
  ExerciseLabelEntry({
    required this.exerciseId,
    required Iterable<String> labels,
    required this.revision,
  }) : labels = List.unmodifiable(labels);
  final String exerciseId;
  final List<String> labels;
  final int revision;
}

/// Organización privada por cuenta y contexto. No cambia el ejercicio.
abstract interface class ExerciseCatalogLabels {
  String newOperationId();
  Future<List<ExerciseLabelEntry>> readLabels();
  Future<ExerciseLabelEntry> setLabels(
    String exerciseId,
    List<String> labels, {
    required int expectedRevision,
    required String operationId,
  });
}
