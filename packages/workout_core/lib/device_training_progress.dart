enum DeviceTrainingPhase {
  notSent,
  pending,
  sending,
  sent,
  changePending,
  updating,
  cancellationPending,
  cancelling,
  cancelled,
  retryPending,
  review,
  blocked,
  unsupported,
  started,
  completed,
}

/// Proyección de entrega de una cita. No contiene concesiones, identidad del
/// fabricante ni mediciones; recibirla no autoriza operaciones de escritura.
class DeviceTrainingProgress {
  const DeviceTrainingProgress({
    required this.id,
    required this.name,
    required this.date,
    required this.phase,
    this.reason,
    this.resultsConfirmed = false,
    this.hasDelivery = false,
    this.executionId,
  });

  factory DeviceTrainingProgress.fromJson(Map<String, dynamic> json) {
    const phases = {
      'not_sent': DeviceTrainingPhase.notSent,
      'pending': DeviceTrainingPhase.pending,
      'sending': DeviceTrainingPhase.sending,
      'sent': DeviceTrainingPhase.sent,
      'change_pending': DeviceTrainingPhase.changePending,
      'updating': DeviceTrainingPhase.updating,
      'cancellation_pending': DeviceTrainingPhase.cancellationPending,
      'cancelling': DeviceTrainingPhase.cancelling,
      'cancelled': DeviceTrainingPhase.cancelled,
      'retry_pending': DeviceTrainingPhase.retryPending,
      'review': DeviceTrainingPhase.review,
      'blocked': DeviceTrainingPhase.blocked,
      'unsupported': DeviceTrainingPhase.unsupported,
      'started': DeviceTrainingPhase.started,
      'completed': DeviceTrainingPhase.completed,
    };
    final phase = phases[json['state']];
    if (phase == null ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['name'] is! String ||
        json['date'] is! String ||
        DateTime.tryParse(json['date'] as String) == null) {
      throw const FormatException('Estado de entrega incompatible.');
    }
    return DeviceTrainingProgress(
      id: json['id'] as String,
      name: json['name'] as String,
      date: json['date'] as String,
      phase: phase,
      reason: json['reason'] as String?,
      resultsConfirmed: json['results_confirmed'] == true,
      hasDelivery: json['has_delivery'] == true,
      executionId: json['execution_id'] as String?,
    );
  }

  final String id, name, date;
  final DeviceTrainingPhase phase;
  final String? reason, executionId;
  final bool resultsConfirmed, hasDelivery;
}
