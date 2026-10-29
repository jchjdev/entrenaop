import 'package:flutter/material.dart';

/// Las colecciones son vistas de las etiquetas privadas ya guardadas; no copian
/// ejercicios ni alteran su autoría. La cadena vacía identifica los no agrupados.
bool matchesExerciseCollection(Iterable<String> labels, String? collection) =>
    collection == null ||
    (collection.isEmpty ? labels.isEmpty : labels.contains(collection));

class ExerciseCollections extends StatelessWidget {
  const ExerciseCollections({
    super.key,
    required this.memberships,
    required this.selected,
    required this.onChanged,
  });
  final List<List<String>> memberships;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final labels in memberships) {
      for (final label in labels.toSet()) {
        counts.update(label, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final names = counts.keys.toList()..sort();
    final ungrouped = memberships.where((labels) => labels.isEmpty).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Colecciones', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Crea una colección desde el botón de etiquetas de cualquier ejercicio. Puede pertenecer a varias; las verás también en el creador de sesiones.',
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Todos (${memberships.length})'),
                    selected: selected == null,
                    onSelected: (_) => onChanged(null),
                  ),
                  ChoiceChip(
                    label: Text('Sin colección ($ungrouped)'),
                    selected: selected == '',
                    onSelected: (_) => onChanged(''),
                  ),
                  for (final name in names)
                    ChoiceChip(
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      label: Text('$name (${counts[name]})'),
                      selected: selected == name,
                      onSelected: (_) =>
                          onChanged(selected == name ? null : name),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
