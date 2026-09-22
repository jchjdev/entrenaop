import 'package:flutter/services.dart';

/// Permite escribir tiempos solo con dígitos: 128 se muestra como 1:28 y
/// 10205 como 1:02:05. Así se evitan cambios de teclado durante el registro.
class DurationInputFormatter extends TextInputFormatter {
  const DurationInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) return oldValue;
    final formatted = formatDurationDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatDurationDigits(String digits) {
  if (digits.isEmpty) return '';
  final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (normalized.length <= 2) return '0:${normalized.padLeft(2, '0')}';
  if (normalized.length <= 4) {
    final split = normalized.length - 2;
    return '${normalized.substring(0, split)}:${normalized.substring(split)}';
  }
  final hoursEnd = normalized.length - 4;
  return '${normalized.substring(0, hoursEnd)}:'
      '${normalized.substring(hoursEnd, hoursEnd + 2)}:'
      '${normalized.substring(hoursEnd + 2)}';
}

int? parseDurationInput(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final parsed = parts.map(int.tryParse).toList(growable: false);
  if (parsed.any((part) => part == null)) return null;
  if (parts.length == 2) {
    final minutes = parsed[0]!;
    final seconds = parsed[1]!;
    if (seconds > 59) return null;
    return minutes * 60 + seconds;
  }
  final hours = parsed[0]!;
  final minutes = parsed[1]!;
  final seconds = parsed[2]!;
  if (minutes > 59 || seconds > 59) return null;
  return hours * 3600 + minutes * 60 + seconds;
}
