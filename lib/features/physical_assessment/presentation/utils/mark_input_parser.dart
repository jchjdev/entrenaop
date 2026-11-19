import 'package:workout_core/performance_time.dart';

int? parseRepetitions(String input) {
  final value = int.tryParse(input.trim());
  return value != null && value >= 0 ? value : null;
}

int? parseSecondsToMilliseconds(String input) {
  // En español es habitual escribir 15,4. Normalizamos la coma antes de
  // convertir y almacenamos milisegundos para no depender de decimales.
  final normalized = input.trim().replaceAll(',', '.');
  final seconds = parsePerformanceTime(normalized);
  return seconds != null && seconds > 0 ? (seconds * 1000).round() : null;
}

int? parseClockToMilliseconds(String input) {
  // El grupo de segundos queda limitado a 00-59 para rechazar valores como
  // 11:72 en lugar de interpretarlos silenciosamente.
  final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(input.trim());
  if (match == null) return null;
  final totalSeconds =
      int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  return totalSeconds > 0 ? totalSeconds * 1000 : null;
}

int? parseFasAgilityMilliseconds(String input) {
  final match = RegExp(r'^(\d*)(?:[.,](\d*))?$').firstMatch(input.trim());
  if (match == null) return null;
  final whole = match[1]!;
  final seconds = whole.isEmpty ? 0 : int.tryParse(whole);
  // Se descartan decimales submilisegundo antes de puntuar a la décima inferior.
  final milliseconds = int.parse(
    (match[2] ?? '').padRight(3, '0').substring(0, 3),
  );
  if (seconds == null || seconds > (9007199254740991 - milliseconds) ~/ 1000) {
    return null;
  }
  final value = seconds * 1000 + milliseconds;
  return value > 0 ? value : null;
}

int? parseWholeSecondsDuration(String input) {
  final trimmed = input.trim();
  if (trimmed.contains(':')) {
    final value = parseClockToMilliseconds(trimmed);
    return value != null && value % 1000 == 0 ? value : null;
  }
  final seconds = int.tryParse(trimmed);
  return seconds != null && seconds > 0 ? seconds * 1000 : null;
}
