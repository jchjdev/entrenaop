import 'package:flutter/services.dart';

/// Admite tanto la entrada abreviada (128 → 1:28) como los dos puntos escritos
/// por el usuario. Una entrada manual nunca debe convertirse en otro tiempo.
class DurationInputFormatter extends TextInputFormatter {
  const DurationInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!RegExp(r'^[0-9:]*$').hasMatch(newValue.text)) return oldValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6 || ':'.allMatches(newValue.text).length > 2) {
      return oldValue;
    }
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final oldWasAutomatic = oldValue.text == formatDurationDigits(oldDigits);
    if (oldWasAutomatic && newValue.text == '${oldValue.text}:') {
      final normalized = oldDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      final explicit = normalized.length <= 2 ? '$normalized:' : newValue.text;
      return TextEditingValue(
        text: explicit,
        selection: TextSelection.collapsed(offset: explicit.length),
      );
    }
    if (newValue.text.contains(':') &&
        !(oldWasAutomatic &&
            newValue.text.startsWith(oldValue.text) &&
            newValue.text.length > oldValue.text.length &&
            RegExp(
              r'^\d+$',
            ).hasMatch(newValue.text.substring(oldValue.text.length)))) {
      return newValue;
    }
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
