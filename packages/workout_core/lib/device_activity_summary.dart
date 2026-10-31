/// Evidencia recibida para una pauta. No acredita por sí sola sus series ni RPE.
class DeviceActivitySummary {
  const DeviceActivitySummary({
    required this.id,
    required this.scheduledId,
    required this.name,
    required this.startedAt,
    required this.seconds,
    required this.state,
    this.meters,
    this.averageHeartRate,
    this.maxHeartRate,
  });

  factory DeviceActivitySummary.fromJson(Map<String, dynamic> json) {
    final seconds = json['timer_seconds'];
    final meters = json['distance_meters'];
    if (seconds is! num ||
        !seconds.isFinite ||
        seconds <= 0 ||
        meters != null && (meters is! num || !meters.isFinite || meters < 0) ||
        !const ['associated', 'review', 'test'].contains(json['state'])) {
      throw const FormatException('Resultado del reloj incompatible.');
    }
    return DeviceActivitySummary(
      id: json['id'] as String,
      scheduledId: json['scheduled_id'] as String,
      name: json['name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      seconds: seconds.toDouble(),
      meters: (meters as num?)?.toDouble(),
      state: json['state'] as String,
      averageHeartRate: (json['average_heart_rate'] as num?)?.round(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.round(),
    );
  }

  final String id, scheduledId, name, state;
  final DateTime startedAt;
  final double seconds;
  final double? meters;
  final int? averageHeartRate, maxHeartRate;
}
