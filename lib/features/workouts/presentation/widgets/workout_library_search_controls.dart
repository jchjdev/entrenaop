import 'package:entrenaop/features/library/presentation/widgets/library_search_controls.dart';
import 'package:entrenaop/features/workouts/presentation/workout_library_filter.dart';
import 'package:flutter/material.dart';

/// Biblioteca y los selectores de sesiones comparten controles y opciones.
class WorkoutLibrarySearchControls extends StatelessWidget {
  const WorkoutLibrarySearchControls({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onDurationChanged,
    required this.onReset,
    required this.resultCount,
    required this.totalCount,
    super.key,
  });

  final TextEditingController controller;
  final WorkoutLibraryFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LibrarySessionType?> onTypeChanged;
  final ValueChanged<LibrarySessionDuration?> onDurationChanged;
  final VoidCallback onReset;
  final int resultCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) => LibrarySearchControls(
    controller: controller,
    searchLabel: 'Buscar sesiones',
    onQueryChanged: onQueryChanged,
    onReset: onReset,
    activeFilters:
        (filter.type == null ? 0 : 1) + (filter.duration == null ? 0 : 1),
    resultCount: resultCount,
    totalCount: totalCount,
    resultNoun: 'sesiones',
    filterFields: [
      LibraryFilterField(
        label: 'Tipo de sesión',
        value: filter.type?.name,
        options: const {
          'strength': 'Fuerza y acondicionamiento',
          'running': 'Carrera',
        },
        onChanged: (value) => onTypeChanged(
          value == null ? null : LibrarySessionType.values.byName(value),
        ),
      ),
      LibraryFilterField(
        label: 'Duración',
        value: filter.duration?.name,
        options: const {
          'short': 'Menos de 30 min',
          'medium': 'De 30 a 45 min',
          'long': 'Más de 45 min',
        },
        onChanged: (value) => onDurationChanged(
          value == null ? null : LibrarySessionDuration.values.byName(value),
        ),
      ),
    ],
  );
}
