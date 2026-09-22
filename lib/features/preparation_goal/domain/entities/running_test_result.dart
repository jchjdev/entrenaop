class RunningTestResult {
  const RunningTestResult({
    required this.completedAt,
    required this.durationSeconds,
    required this.rpe,
    this.averageHrBpm,
    this.maxHrBpm,
    this.notes,
    this.splitsSeconds,
  });

  final DateTime completedAt;
  final int durationSeconds;
  final int rpe;
  final int? averageHrBpm;
  final int? maxHrBpm;
  final String? notes;
  final List<int>? splitsSeconds;

  String? validate() {
    if (durationSeconds < 120 || durationSeconds > 7200) {
      return 'Introduce un tiempo válido para los 2 km.';
    }
    if (rpe < 1 || rpe > 10) return 'Indica un esfuerzo del 1 al 10.';
    if ((averageHrBpm != null && (averageHrBpm! < 30 || averageHrBpm! > 250)) ||
        (maxHrBpm != null && (maxHrBpm! < 30 || maxHrBpm! > 250)) ||
        (averageHrBpm != null &&
            maxHrBpm != null &&
            averageHrBpm! > maxHrBpm!)) {
      return 'Revisa la frecuencia cardíaca.';
    }
    if ((notes?.length ?? 0) > 1000) return 'La nota es demasiado larga.';
    final splits = splitsSeconds;
    if (splits != null &&
        (splits.length != 5 ||
            splits.any((seconds) => seconds <= 0) ||
            splits.fold<int>(0, (sum, seconds) => sum + seconds) !=
                durationSeconds)) {
      return 'Los cinco parciales de 400 m deben sumar el tiempo total.';
    }
    return null;
  }
}
