/// Convierte el texto de una duración sin interpretar minutos decimales.
/// «1:30» y «90» significan noventa segundos; «13,25» conserva centésimas.
double? parsePerformanceTime(String text) {
  final clean = text.trim().replaceAll(',', '.');
  final parts = clean.split(':');
  if (parts.length == 1) {
    final value = double.tryParse(clean);
    return value != null && value.isFinite && value >= 0 ? value : null;
  }
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = double.tryParse(parts[1]);
  if (minutes == null ||
      minutes < 0 ||
      seconds == null ||
      !seconds.isFinite ||
      seconds < 0 ||
      seconds >= 60) {
    return null;
  }
  return minutes * 60 + seconds;
}

String formatPerformanceTime(num seconds) {
  final rounded = (seconds * 100).round() / 100;
  final minutes = rounded ~/ 60;
  final remainder = rounded % 60;
  final tail = remainder == remainder.truncate()
      ? remainder.toInt().toString().padLeft(2, '0')
      : remainder.toStringAsFixed(2).padLeft(5, '0');
  return '$minutes:$tail';
}
