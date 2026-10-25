import 'workout_editor_card.dart';

/// Compatibilidad del creador de carrera sobre la tarjeta común de autoría.
class RunningStepCard extends WorkoutEditorCard {
  const RunningStepCard({
    super.key,
    required super.index,
    required super.title,
    required super.summary,
    required super.color,
    required super.expanded,
    required super.onToggle,
    required super.menu,
    required super.editor,
    super.dragHandle,
    super.propertiesInPanel,
    super.selected,
  }) : super(headerKeyPrefix: 'running-step-header');
}
