/// Alcance de la prescripción; no altera las pruebas del catálogo ni el historial.
enum TrainingScope {
  full('full'),
  running('running'),
  performance('performance');

  const TrainingScope(this.value);
  final String value;
  bool get includesRunning => this != performance;
  bool get includesPerformance => this != running;

  static TrainingScope parse(Object? value) =>
      values.where((scope) => scope.value == value).firstOrNull ?? full;
}
