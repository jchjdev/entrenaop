import 'package:flutter/material.dart';

/// Mantiene legibles las opciones largas, también con el texto ampliado.
class PreparationSelectField<T> extends StatelessWidget {
  const PreparationSelectField({
    required this.decoration,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.validator,
    this.menuMaxHeight,
    super.key,
  });

  final T? initialValue;
  final InputDecoration decoration;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final double? menuMaxHeight;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: initialValue,
    isExpanded: true,
    isDense: false,
    itemHeight: null,
    menuMaxHeight: menuMaxHeight,
    decoration: decoration.copyWith(errorMaxLines: 3),
    items: [
      for (final item in items)
        DropdownMenuItem(
          value: item.value,
          enabled: item.enabled,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: item.child,
          ),
        ),
    ],
    selectedItemBuilder: (_) => [
      for (final item in items)
        Align(alignment: Alignment.centerLeft, child: item.child),
    ],
    onChanged: onChanged,
    validator: validator,
  );
}
