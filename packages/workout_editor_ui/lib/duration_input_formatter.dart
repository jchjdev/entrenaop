import 'package:flutter/services.dart';

/// Entrada abreviada (130 → 01:30) o reloj explícito, sin necesitar «:»
/// en el teclado móvil. Las fracciones se habilitan solo donde se admiten.
class DurationInputFormatter extends TextInputFormatter {
  const DurationInputFormatter({this.allowFraction = false});
  final bool allowFraction;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    final allowed = allowFraction
        ? RegExp(r'^[0-9:]*(?:\.\d*)?$')
        : RegExp(r'^[0-9:]*$');
    if (!allowed.hasMatch(text)) return oldValue;
    if (text.isEmpty) return newValue;
    final sections = text.split('.');
    final whole = sections.first;
    final digits = whole.replaceAll(':', '');
    if (digits.replaceFirst(RegExp(r'^0+(?=\d)'), '').length > 6 ||
        ':'.allMatches(whole).length > 2) {
      return oldValue;
    }
    if (sections.length == 2) {
      final clock = whole.contains(':')
          ? _padClock(whole)
          : formatDurationDigits(whole);
      if (clock.isEmpty || clock.split(':').last.length != 2) return oldValue;
      return _value('$clock.${sections[1]}');
    }
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final automatic = oldValue.text == formatDurationDigits(oldDigits);
    // Borrar retira un dígito real; los ceros de la máscara no atrapan el campo.
    if (automatic &&
        oldValue.text.isNotEmpty &&
        text == oldValue.text.substring(0, oldValue.text.length - 1)) {
      final significant = oldDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      return _value(
        formatDurationDigits(significant.substring(0, significant.length - 1)),
      );
    }
    if (automatic && text == '${oldValue.text}:') {
      final significant = oldDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      return _value(significant.length <= 2 ? '$significant:' : whole);
    }
    final appendedDigits =
        automatic &&
        text.startsWith(oldValue.text) &&
        text.length > oldValue.text.length &&
        RegExp(r'^\d+$').hasMatch(text.substring(oldValue.text.length));
    if (whole.contains(':') && !appendedDigits) {
      final padded = _padClock(whole);
      return padded == newValue.text ? newValue : _value(padded);
    }
    return _value(formatDurationDigits(digits));
  }

  String _padClock(String text) {
    final parts = text.split(':');
    if (parts.length == 2 && parts.first.isNotEmpty && parts.last.length == 2) {
      return '${parts.first.padLeft(2, '0')}:${parts.last}';
    }
    return text;
  }

  TextEditingValue _value(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

String formatDurationDigits(String digits) {
  if (digits.isEmpty) return '';
  final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (normalized.length <= 2) return '00:${normalized.padLeft(2, '0')}';
  if (normalized.length <= 4) {
    final split = normalized.length - 2;
    return '${normalized.substring(0, split).padLeft(2, '0')}:${normalized.substring(split)}';
  }
  final hoursEnd = normalized.length - 4;
  return '${normalized.substring(0, hoursEnd).padLeft(2, '0')}:'
      '${normalized.substring(hoursEnd, hoursEnd + 2)}:'
      '${normalized.substring(hoursEnd + 2)}';
}

int? parseDurationInput(String value) {
  final clean = value.trim();
  if (!RegExp(r'^\d+:\d{2}(?::\d{2})?$').hasMatch(clean)) return null;
  final parts = clean.split(':').map(int.parse).toList();
  if (parts.last > 59 || parts.length == 3 && parts[1] > 59) return null;
  return parts.length == 2
      ? parts[0] * 60 + parts[1]
      : parts[0] * 3600 + parts[1] * 60 + parts[2];
}

/// Presentación de segundos ya almacenados: 90 → 01:30, no 00:90.
/// Conserva la precisión decimal de la marca, sin redondearla a segundos.
String formatDurationSeconds(num seconds) {
  final whole = seconds.floor();
  final minutes = (whole ~/ 60).toString().padLeft(2, '0');
  final tail = (whole % 60).toString().padLeft(2, '0');
  final raw = seconds.toString();
  final decimal = raw.contains('e') ? seconds.toStringAsFixed(12) : raw;
  final fraction = decimal.contains('.')
      ? decimal.split('.').last.replaceFirst(RegExp(r'0+$'), '')
      : '';
  return '$minutes:$tail${fraction.isEmpty ? '' : '.$fraction'}';
}
