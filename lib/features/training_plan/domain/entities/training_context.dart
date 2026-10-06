class TrainingContext {
  TrainingContext({
    required Map<String, int> availability,
    required Set<String> equipment,
    required this.reportsPain,
    required this.capacityConfirmed,
    this.observedAt,
  }) : availability = Map.unmodifiable(availability),
       equipment = Set.unmodifiable(equipment);

  final Map<String, int> availability;
  final Set<String> equipment;
  final bool reportsPain;
  final bool capacityConfirmed;
  final DateTime? observedAt;
}

class TrainingContextSettings {
  TrainingContextSettings({
    this.context,
    required Set<String> equipmentOptions,
    this.previousSessionMinutes,
    this.previousDaysPerWeek,
    this.previousReportsLimitation = false,
    this.previousPullUpBar = false,
  }) : equipmentOptions = Set.unmodifiable(equipmentOptions);

  final TrainingContext? context;
  final Set<String> equipmentOptions;
  // Preferencias antiguas: ayudan a completar el contexto, no confirman días
  // concretos ni convierten «gimnasio/pesas» en material específico.
  final int? previousSessionMinutes;
  final int? previousDaysPerWeek;
  final bool previousReportsLimitation;
  final bool previousPullUpBar;
}
