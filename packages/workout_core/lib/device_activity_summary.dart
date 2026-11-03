/// Evidencia del reloj, asociada a una pauta o pendiente de asociación.
/// Recibirla no acredita por sí solo sus series ni RPE.
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
    this.executionId,
    this.intervalCount = 0,
    this.effortScore,
    this.provider = 'apple',
    this.scheduledName,
    this.intervals = const [],
    this.detailsIncomplete = false,
  });

  factory DeviceActivitySummary.fromJson(Map<String, dynamic> json) {
    final seconds = json['timer_seconds'];
    final meters = json['distance_meters'];
    final scheduledId = json['scheduled_id'];
    final provider = json['provider'] ?? 'apple';
    if (seconds is! num ||
        !seconds.isFinite ||
        seconds <= 0 ||
        meters != null && (meters is! num || !meters.isFinite || meters < 0) ||
        !const ['apple', 'garmin'].contains(provider) ||
        !const [
          'associated',
          'review',
          'test',
          'unassigned',
        ].contains(json['state']) ||
        (json['state'] == 'unassigned'
            ? scheduledId != null || json['execution_id'] != null
            : scheduledId is! String || scheduledId.isEmpty)) {
      throw const FormatException('Resultado del reloj incompatible.');
    }
    return DeviceActivitySummary(
      id: json['id'] as String,
      scheduledId: scheduledId as String?,
      name: json['name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      seconds: seconds.toDouble(),
      meters: (meters as num?)?.toDouble(),
      state: json['state'] as String,
      averageHeartRate: (json['average_heart_rate'] as num?)?.round(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.round(),
      executionId: json['execution_id'] as String?,
      intervalCount: json['interval_count'] as int? ?? 0,
      effortScore: (json['effort_score'] as num?)?.toDouble(),
      provider: provider as String,
      scheduledName: json['scheduled_name'] as String?,
      intervals: List.unmodifiable(
        (json['intervals'] as List? ?? const []).map(
          (row) => DeviceActivityInterval.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        ),
      ),
      detailsIncomplete: json['details_incomplete'] == true,
    );
  }

  final String id, name, state, provider;
  final String? scheduledId;
  final String? scheduledName;
  final DateTime startedAt;
  final double seconds;
  final double? meters;
  final int? averageHeartRate, maxHeartRate;
  final String? executionId;
  final int intervalCount;
  final double? effortScore;
  final List<DeviceActivityInterval> intervals;
  final bool detailsIncomplete;
  double? get paceSecondsPerKm => _recordedPace(seconds, meters);
}

/// Intervalo medido por el dispositivo. Su orden no acredita una serie pautada.
class DeviceActivityInterval {
  const DeviceActivityInterval({
    required this.index,
    required this.seconds,
    this.meters,
    this.averageHeartRate,
  });
  factory DeviceActivityInterval.fromJson(Map<String, dynamic> json) {
    final index = json['index'];
    final seconds = json['timer_seconds'];
    final meters = json['distance_meters'];
    if (index is! int ||
        index < 1 ||
        index > 100 ||
        seconds is! num ||
        !seconds.isFinite ||
        seconds <= 0 ||
        meters != null && (meters is! num || !meters.isFinite || meters < 0)) {
      throw const FormatException('Intervalo del reloj incompatible.');
    }
    return DeviceActivityInterval(
      index: index,
      seconds: seconds.toDouble(),
      meters: (meters as num?)?.toDouble(),
      averageHeartRate: (json['average_heart_rate'] as num?)?.round(),
    );
  }
  final int index;
  final double seconds;
  final double? meters;
  final int? averageHeartRate;
  double? get paceSecondsPerKm => _recordedPace(seconds, meters);
}

// Usamos el temporizador original y los metros medidos, nunca la distancia
// pautada ni el tiempo transcurrido que incluye las pausas del reloj.
double? _recordedPace(double seconds, double? meters) {
  if (!seconds.isFinite ||
      seconds <= 0 ||
      meters == null ||
      !meters.isFinite ||
      meters <= 0) {
    return null;
  }
  final pace = seconds / meters * 1000;
  return pace.isFinite && pace > 0 ? pace : null;
}
