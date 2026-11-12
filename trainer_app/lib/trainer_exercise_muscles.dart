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
  'biceps': 'bíceps',
  'triceps': 'tríceps',
};

List<String> trainerExerciseMuscles(Iterable<String> values) => {
  for (final value in values)
    if (value.trim().isNotEmpty)
      normalizeCatalogSearch(_muscleLabel(value)): _muscleLabel(value),
}.values.toList(growable: false);

String _muscleLabel(String value) =>
    _aliases[normalizeCatalogSearch(value)] ?? value.trim();

Iterable<String> trainerExerciseMuscleSearchTerms(Iterable<String> muscles) {
  final labels = muscles.toSet();
  return [
    ...labels,
    for (final alias in _aliases.entries)
      if (labels.contains(alias.value)) alias.key,
  ];
}
