import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryFilters extends StatelessWidget {
  const WorkoutHistoryFilters({
    required this.query,
    required this.goals,
    required this.onChanged,
    super.key,
  });
  final WorkoutHistoryQuery query;
  final List<PreparationGoal> goals;
  final ValueChanged<WorkoutHistoryQuery> onChanged;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Filtrar historial'),
    subtitle: query.hasFilters ? const Text('Filtros aplicados') : null,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('history-goal-${query.preparationGoalId}'),
        initialValue: query.preparationGoalId ?? '',
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Preparación'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Todas las sesiones')),
          for (final goal in goals.where((g) => g.id != null))
            DropdownMenuItem(value: goal.id!, child: Text(goal.program.name)),
          if (query.preparationGoalId != null &&
              !goals.any((g) => g.id == query.preparationGoalId))
            DropdownMenuItem(
              value: query.preparationGoalId,
              child: const Text('Preparación seleccionada'),
            ),
        ],
        selectedItemBuilder: (_) => [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Todas las sesiones'),
          ),
          for (final goal in goals.where((g) => g.id != null))
            Align(
              alignment: Alignment.centerLeft,
              child: Text(goal.program.name),
            ),
          if (query.preparationGoalId != null &&
              !goals.any((g) => g.id == query.preparationGoalId))
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Preparación seleccionada'),
            ),
        ],
        onChanged: (value) => onChanged(
          WorkoutHistoryQuery(
            preparationGoalId: value == '' ? null : value,
            from: query.from,
            through: query.through,
            status: query.status,
            sessionType: query.sessionType,
          ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('history-type-${query.sessionType}'),
        initialValue: query.sessionType?.name ?? '',
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Tipo de entrenamiento'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Todos los tipos')),
          for (final type in WorkoutSessionType.values)
            DropdownMenuItem(value: type.name, child: Text(type.label)),
        ],
        selectedItemBuilder: (_) => [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Todos los tipos'),
          ),
          for (final type in WorkoutSessionType.values)
            Align(alignment: Alignment.centerLeft, child: Text(type.label)),
        ],
        onChanged: (value) => onChanged(
          WorkoutHistoryQuery(
            preparationGoalId: query.preparationGoalId,
            from: query.from,
            through: query.through,
            status: query.status,
            sessionType: value == '' || value == null
                ? null
                : WorkoutSessionType.values.byName(value),
          ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('history-status-${query.status}'),
        initialValue: query.status?.name ?? '',
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Estado de la sesión'),
        items: const [
          DropdownMenuItem(value: '', child: Text('Todos los estados')),
          DropdownMenuItem(value: 'completed', child: Text('Completadas')),
          DropdownMenuItem(
            value: 'abandoned',
            child: Text('Cerradas sin completar'),
          ),
        ],
        selectedItemBuilder: (_) => const [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Todos los estados'),
          ),
          Align(alignment: Alignment.centerLeft, child: Text('Completadas')),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Cerradas sin completar'),
          ),
        ],
        onChanged: (value) => onChanged(
          WorkoutHistoryQuery(
            preparationGoalId: query.preparationGoalId,
            from: query.from,
            through: query.through,
            sessionType: query.sessionType,
            status: value == '' || value == null
                ? null
                : WorkoutExecutionStatus.values.byName(value),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              query.from == null || query.through == null
                  ? 'Elegir fechas'
                  : '${DateFormat('dd/MM/yyyy').format(query.from!)} – ${DateFormat('dd/MM/yyyy').format(query.through!)}',
            ),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(1970),
                lastDate: DateTime.now(),
                initialDateRange: query.from == null || query.through == null
                    ? null
                    : DateTimeRange(start: query.from!, end: query.through!),
              );
              if (range != null && context.mounted) {
                onChanged(
                  WorkoutHistoryQuery(
                    preparationGoalId: query.preparationGoalId,
                    status: query.status,
                    sessionType: query.sessionType,
                    from: range.start,
                    through: range.end,
                  ),
                );
              }
            },
          ),
          if (query.hasFilters)
            TextButton(
              onPressed: () => onChanged(const WorkoutHistoryQuery()),
              child: const Text('Limpiar filtros'),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
}
