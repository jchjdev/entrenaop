import 'package:flutter/services.dart';

/// Agilidad se introduce en segundos decimales, sin máscara de minutos.
/// Conserva coma, punto y posición del cursor al corregir una marca.
class SecondsInputFormatter extends TextInputFormatter {
  const SecondsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RegExp(r'^\d*(?:[.,]\d*)?$').hasMatch(newValue.text)
      ? newValue
      : oldValue;
}
