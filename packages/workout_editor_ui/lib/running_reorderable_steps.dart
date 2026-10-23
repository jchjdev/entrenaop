import 'workout_reorderable_cards.dart';

/// Conserva las claves y el nombre accesible del creador de carrera.
class RunningReorderableSteps extends WorkoutReorderableCards {
  const RunningReorderableSteps({
    super.key,
    required super.identities,
    required super.itemBuilder,
    required super.feedbackBuilder,
    required super.onReorder,
    super.enabled,
  }) : super(keyPrefix: 'running-drag-handle', itemLabel: 'tramo');
}
