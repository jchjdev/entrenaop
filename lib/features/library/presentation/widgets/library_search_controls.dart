import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';

class LibrarySearchControls extends StatefulWidget {
  const LibrarySearchControls({
    required this.controller,
    required this.searchLabel,
    required this.onQueryChanged,
    required this.onReset,
    required this.filterFields,
    required this.activeFilters,
    required this.resultCount,
    required this.totalCount,
    required this.resultNoun,
    super.key,
  });

  final TextEditingController controller;
  final String searchLabel;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onReset;
  final List<Widget> filterFields;
  final int activeFilters;
  final int resultCount;
  final int totalCount;
  final String resultNoun;

  @override
  State<LibrarySearchControls> createState() => _LibrarySearchControlsState();
}

class _LibrarySearchControlsState extends State<LibrarySearchControls> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: widget.controller,
        onChanged: widget.onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: widget.searchLabel,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar texto',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onQueryChanged('');
                  },
                ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.tune_rounded,
            ),
            label: Text(
              widget.activeFilters == 0
                  ? 'Filtros'
                  : 'Filtros (${widget.activeFilters})',
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              '${widget.resultCount} de ${widget.totalCount} ${widget.resultNoun}',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ),
          if (widget.controller.text.isNotEmpty || widget.activeFilters > 0)
            TextButton(
              onPressed: widget.onReset,
              child: const Text('Limpiar búsqueda y filtros'),
            ),
        ],
      ),
      if (_expanded) ...[
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 640 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 22
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final field in widget.filterFields)
                  SizedBox(width: width, child: field),
              ],
            );
          },
        ),
      ],
    ],
  );
}

class LibraryFilterField extends StatelessWidget {
  const LibraryFilterField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Conservar la selección si una recarga ya no contiene ese valor: sigue
    // siendo un filtro real y puede limpiarse, sin un reinicio silencioso.
    final choices = {...options};
    if (value != null && !choices.containsKey(value)) choices[value!] = value!;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${choices.keys.join('|')}'),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Cualquiera')),
        for (final entry in choices.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(
              entry.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => onChanged(value == '' ? null : value),
    );
  }
}
