import 'package:flutter/material.dart';

import 'domain.dart';

Future<Set<String>?> pickDirectorySpecialties(
  BuildContext context, {
  required List<DirectorySpecialty> catalog,
  required Set<String> selected,
  int? maxSelections,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) => _SpecialtyPicker(catalog, selected, maxSelections),
);

class _SpecialtyPicker extends StatefulWidget {
  const _SpecialtyPicker(this.catalog, this.selected, this.maxSelections);
  final List<DirectorySpecialty> catalog;
  final Set<String> selected;
  final int? maxSelections;

  @override
  State<_SpecialtyPicker> createState() => _SpecialtyPickerState();
}

class _SpecialtyPickerState extends State<_SpecialtyPicker> {
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Especialidades'),
    scrollable: true,
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.maxSelections == null
                ? 'Se mostrarán preparadores que ofrezcan alguna de las especialidades marcadas.'
                : 'Elige hasta ${widget.maxSelections} especialidades para tu ficha.',
          ),
          const SizedBox(height: 8),
          for (final item in widget.catalog)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              value: _selected.contains(item.id),
              onChanged:
                  widget.maxSelections != null &&
                      _selected.length >= widget.maxSelections! &&
                      !_selected.contains(item.id)
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(item.id);
                      } else {
                        _selected.remove(item.id);
                      }
                    }),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      if (_selected.isNotEmpty)
        TextButton(
          onPressed: () => setState(_selected.clear),
          child: const Text('Quitar todas'),
        ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _selected),
        child: const Text('Aplicar'),
      ),
    ],
  );
}
