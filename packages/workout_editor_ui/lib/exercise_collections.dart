import 'package:flutter/material.dart';

enum ExerciseCollectionAction { rename, remove }

/// Las colecciones son vistas de las etiquetas privadas ya guardadas; no copian
/// ejercicios ni alteran su autoría. La cadena vacía identifica los no agrupados.
bool matchesExerciseCollection(Iterable<String> labels, String? collection) =>
    collection == null ||
    (collection.isEmpty ? labels.isEmpty : labels.contains(collection));

bool isValidExerciseCollectionName(String name) =>
    name.isNotEmpty &&
    name.runes.length <= 32 &&
    !RegExp(r'[\x00-\x1f\x7f,]').hasMatch(name);

String resolveExerciseCollectionName(String name, Iterable<String> existing) =>
    existing.contains(name)
    ? name
    : existing.firstWhere(
        (collection) => collection.toLowerCase() == name.toLowerCase(),
        orElse: () => name,
      );

class ExerciseCollections extends StatelessWidget {
  const ExerciseCollections({
    super.key,
    required this.memberships,
    required this.selected,
    required this.onChanged,
    this.onManage,
  });
  final List<List<String>> memberships;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final void Function(String, ExerciseCollectionAction)? onManage;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Colecciones', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Tus colecciones también aparecen en el creador de sesiones.',
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                    Builder(
                      builder: (chipContext) => InputChip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: Text('$name (${counts[name]})'),
                        selected: selected == name,
                        onSelected: (_) =>
                            onChanged(selected == name ? null : name),
                        deleteIcon: const Icon(Icons.more_vert, size: 18),
                        deleteButtonTooltipMessage:
                            'Opciones de la colección $name',
                        onDeleted: onManage == null
                            ? null
                            : () async {
                                final overlay =
                                    Navigator.of(chipContext).overlay!.context
                                            .findRenderObject()!
                                        as RenderBox;
                                final chip =
                                    chipContext.findRenderObject()!
                                        as RenderBox;
                                final anchor = chip.localToGlobal(
                                  Offset(chip.size.width, chip.size.height),
                                  ancestor: overlay,
                                );
                                final action =
                                    await showMenu<ExerciseCollectionAction>(
                                      context: chipContext,
                                      position: RelativeRect.fromSize(
                                        Rect.fromLTWH(
                                          anchor.dx,
                                          anchor.dy,
                                          0,
                                          0,
                                        ),
                                        overlay.size,
                                      ),
                                      items: const [
                                        PopupMenuItem(
                                          value:
                                              ExerciseCollectionAction.rename,
                                          child: Text('Renombrar'),
                                        ),
                                        PopupMenuItem(
                                          value:
                                              ExerciseCollectionAction.remove,
                                          child: Text('Eliminar colección'),
                                        ),
                                      ],
                                    );
                                if (action != null && chipContext.mounted) {
                                  onManage!(name, action);
                                }
                              },
                      ),
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
