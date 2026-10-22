class TrainingCandidate {
  const TrainingCandidate(this.id, this.name, this.date, this.source);
  final String id, name, date, source;
}

class TrainingStep {
  const TrainingStep(
    this.kind,
    this.measure,
    this.value,
    this.description,
    this.fast,
    this.slow,
  );
  final String kind, measure, description;
  final double? value;
  final double? fast, slow;
}

class TrainingPreview {
  const TrainingPreview(
    this.revision,
    this.name,
    this.date,
    this.steps, {
    this.description = '',
  });
  final String revision, name, date;
  final String description;
  final List<TrainingStep> steps;
}

class TrainingReceipt {
  const TrainingReceipt(
    this.id,
    this.scheduledId,
    this.status,
    this.name,
    this.date,
    this.error,
  );
  final String id, scheduledId, status, name, date;
  final String? error;
}

class TrainingCatalog {
  const TrainingCatalog(this.candidates, this.deliveries);
  final List<TrainingCandidate> candidates;
  final List<TrainingReceipt> deliveries;
}

class TrainingDeliveryException implements Exception {
  const TrainingDeliveryException(this.code);
  final String code;
}

abstract interface class TrainingDeliveryRepository {
  Future<TrainingCatalog> load();
  Future<TrainingPreview> preview(String scheduledId);
  Future<TrainingReceipt> send(String scheduledId, String revision);
}

class TrainingSyncSettings {
  const TrainingSyncSettings(this.enabled, this.pending, this.review);
  final bool enabled;
  final int pending, review;
}

abstract interface class TrainingSyncRepository {
  Future<TrainingSyncSettings> syncSettings({bool? enabled});
}
