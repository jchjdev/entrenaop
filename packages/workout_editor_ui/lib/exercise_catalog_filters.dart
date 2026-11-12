import 'package:flutter/material.dart';

import 'package:workout_editor_ui/catalog_search.dart';

// Nombres de catálogo. La clasificación guardada de cada versión se conserva.
const _aliases = {
  'pantorrilla': 'gemelos',
  'pantorrillas': 'gemelos',
  'gemelo': 'gemelos',
  'gemelos': 'gemelos',
  'gastrocnemio': 'gemelos',
  'soleo': 'sóleo',
  'isquios': 'isquiotibiales',
  'isquiotibial': 'isquiotibiales',
  'isquiotibiales': 'isquiotibiales',
  'cuadriceps': 'cuádriceps',
  'gluteo': 'glúteos',
  'gluteos': 'glúteos',
  'pectoral': 'pecho',
  'pectorales': 'pecho',
  'biceps': 'bíceps',
  'triceps': 'tríceps',
};

List<String> exerciseMuscleLabels(Iterable<String> values) => {
  for (final value in values)
    if (value.trim().isNotEmpty)
      normalizeCatalogSearch(_muscleLabel(value)): _muscleLabel(value),
}.values.toList(growable: false);

String _muscleLabel(String value) =>
    _aliases[normalizeCatalogSearch(value)] ?? value.trim();

Iterable<String> exerciseMuscleSearchTerms(Iterable<String> muscles) {
  final labels = muscles.toSet();
  return [
    ...labels,
    for (final alias in _aliases.entries)
      if (labels.contains(alias.value)) alias.key,
  ];
}

typedef ExerciseCatalogAttributes = ({
  Iterable<String> muscles,
  Iterable<String> equipment,
});

class ExerciseCatalogFilters {
  ExerciseCatalogFilters(
    Iterable<ExerciseCatalogAttributes> catalog, {
    String? muscle,
    String? equipment,
  }) {
    muscleOptions = _options(
      catalog.expand((exercise) => exerciseMuscleLabels(exercise.muscles)),
    );
    equipmentOptions = _options(
      catalog.expand((exercise) => exercise.equipment),
    );
    this.muscle = muscleOptions.containsKey(muscle) ? muscle : null;
    this.equipment = equipmentOptions.containsKey(equipment) ? equipment : null;
  }

  late final Map<String, String> muscleOptions, equipmentOptions;
  late final String? muscle, equipment;

  bool get hasOptions =>
      muscleOptions.isNotEmpty || equipmentOptions.isNotEmpty;

  bool matches({
    required Iterable<String> muscles,
    required Iterable<String> equipment,
  }) =>
      (muscle == null ||
          muscles.any(
            (value) => normalizeCatalogSearch(_muscleLabel(value)) == muscle,
          )) &&
      (this.equipment == null ||
          equipment.any(
            (value) => normalizeCatalogSearch(value) == this.equipment,
          ));

  static Map<String, String> _options(Iterable<String> values) {
    final options = <String, String>{};
    for (final value in values) {
      final key = normalizeCatalogSearch(value);
      if (key.isNotEmpty) options.putIfAbsent(key, () => value.trim());
    }
    return Map.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }
}

class ExerciseCatalogFilterFields extends StatelessWidget {
  const ExerciseCatalogFilterFields({
    super.key,
    required this.filters,
    required this.onMuscleChanged,
    required this.onEquipmentChanged,
  });

  final ExerciseCatalogFilters filters;
  final ValueChanged<String?> onMuscleChanged, onEquipmentChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      if (filters.muscleOptions.isNotEmpty)
        _field(
          'Músculo',
          'Todos los músculos',
          filters.muscleOptions,
          filters.muscle,
          onMuscleChanged,
        ),
      if (filters.equipmentOptions.isNotEmpty)
        _field(
          'Material',
          'Todo el material',
          filters.equipmentOptions,
          filters.equipment,
          onEquipmentChanged,
        ),
    ],
  );

  Widget _field(
    String label,
    String allLabel,
    Map<String, String> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected'),
      initialValue: selected ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onChanged(value == '' ? null : value),
    ),
  );
}
