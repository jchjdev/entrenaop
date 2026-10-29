import 'package:flutter/material.dart';
import 'package:workout_editor_ui/catalog_search.dart';

import 'trainer_workout_repository.dart';

const trainerWorkoutFormats = {
  'straight_sets': 'Series convencionales',
  'superset': 'Superserie',
  'circuit': 'Circuito',
  'intervals': 'Intervalos',
  'emom': 'EMOM',
  'amrap': 'AMRAP',
  'tabata': 'Tabata',
  'running': 'Carrera',
  'warm_up': 'Calentamiento',
  'cool_down': 'Vuelta a la calma',
};

bool matchesTrainerWorkout(
  TrainerWorkout item, {
  String query = '',
  bool? running,
  String? format,
}) =>
    (running == null || item.isRunning == running) &&
    (format == null || item.formats.contains(format)) &&
    matchesCatalogSearch(query, [
      item.name,
      item.isRunning ? 'Carrera' : 'Fuerza',
      ...item.searchContent,
      for (final f in item.formats) trainerWorkoutFormats[f] ?? f,
    ]);

String trainerWorkoutFormatSummary(TrainerWorkout item) => item.formats
    .where((f) => f != 'running')
    .map((f) => trainerWorkoutFormats[f] ?? f)
    .join(' · ');

class TrainerWorkoutFilters extends StatelessWidget {
  const TrainerWorkoutFilters({
    super.key,
    required this.running,
    required this.format,
    required this.onRunningChanged,
    required this.onFormatChanged,
    this.stacked = false,
    this.popup = false,
  });
  final bool? running;
  final String? format;
  final ValueChanged<bool?> onRunningChanged;
  final ValueChanged<String?> onFormatChanged;
  final bool stacked;
  final bool popup;

  @override
  Widget build(BuildContext context) {
    if (popup) {
      final count = (running == null ? 0 : 1) + (format == null ? 0 : 1);
      return PopupMenuButton<String>(
        tooltip: 'Filtrar sesiones por modalidad y formato',
        onSelected: (value) {
          if (value.startsWith('sport:')) {
            onRunningChanged(
              value == 'sport:all' ? null : value == 'sport:running',
            );
          } else {
            onFormatChanged(value == 'format:all' ? null : value.substring(7));
          }
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'sport:all',
            checked: running == null,
            child: const Text('Todas las modalidades'),
          ),
          CheckedPopupMenuItem(
            value: 'sport:strength',
            checked: running == false,
            child: const Text('Fuerza'),
          ),
          CheckedPopupMenuItem(
            value: 'sport:running',
            checked: running == true,
            child: const Text('Carrera'),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'format:all',
            checked: format == null,
            child: const Text('Todos los formatos'),
          ),
          for (final entry in trainerWorkoutFormats.entries)
            CheckedPopupMenuItem(
              value: 'format:${entry.key}',
              checked: format == entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            count == 0 ? 'Filtros' : 'Filtros ($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    final modality = DropdownButtonFormField<String>(
      key: ValueKey('workout-modality:$running'),
      initialValue: running == null
          ? ''
          : running!
          ? 'running'
          : 'strength',
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Modalidad'),
      items: const [
        DropdownMenuItem(value: '', child: Text('Todas')),
        DropdownMenuItem(value: 'strength', child: Text('Fuerza')),
        DropdownMenuItem(value: 'running', child: Text('Carrera')),
      ],
      onChanged: (value) =>
          onRunningChanged(value == '' ? null : value == 'running'),
    );
    final blockFormat = DropdownButtonFormField<String>(
      key: ValueKey('workout-format:$format'),
      initialValue: format ?? '',
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Contiene formato'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos')),
        for (final entry in trainerWorkoutFormats.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onFormatChanged(value == '' ? null : value),
    );
    final vertical =
        stacked ||
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    // Los diálogos calculan dimensiones intrínsecas: no usar LayoutBuilder aquí.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [modality, const SizedBox(height: 12), blockFormat],
            )
          : Row(
              children: [
                Expanded(child: modality),
                const SizedBox(width: 12),
                Expanded(child: blockFormat),
              ],
            ),
    );
  }
}
