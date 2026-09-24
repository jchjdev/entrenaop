int? parseRepetitions(String input) {
  final value = int.tryParse(input.trim());
  return value != null && value >= 0 ? value : null;
}

int? parseSecondsToMilliseconds(String input) {
  // En español es habitual escribir 15,4. Normalizamos la coma antes de
  // convertir y almacenamos milisegundos para no depender de decimales.
  final normalized = input.trim().replaceAll(',', '.');
  final seconds = double.tryParse(normalized);
  return seconds != null && seconds > 0 ? (seconds * 1000).round() : null;
}

int? parseClockToMilliseconds(String input) {
  // El grupo de segundos queda limitado a 00-59 para rechazar valores como
  // 11:72 en lugar de interpretarlos silenciosamente.
  final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(input.trim());
  if (match == null) return null;

  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final totalSeconds = minutes * 60 + seconds;
  return totalSeconds > 0 ? totalSeconds * 1000 : null;
}

int? parseWholeSecondsDuration(String input) {
  final trimmed = input.trim();
  if (trimmed.contains(':')) return parseClockToMilliseconds(trimmed);
  final seconds = int.tryParse(trimmed);
  return seconds != null && seconds > 0 ? seconds * 1000 : null;
}
