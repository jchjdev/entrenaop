import 'package:flutter/material.dart';

Future<DateTime?> chooseBirthDate(BuildContext context, {DateTime? current}) {
  final today = DateTime.now();
  final first = DateTime(today.year - 120, today.month, today.day);
  final last = DateTime(today.year - 17, today.month, today.day);
  final initial =
      current == null || current.isBefore(first) || current.isAfter(last)
      ? DateTime(today.year - 25, today.month, today.day)
      : current;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: 'Fecha de nacimiento',
  );
}
