import 'dart:math' as math;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';

/// Presentación local: el color depende de la identidad, no del orden de carga.
Color trainerCalendarColor(String personId) {
  const palette = [
    Color(0xff38bdf8),
    Color(0xffa78bfa),
    Color(0xff34d399),
    Color(0xfffb923c),
    Color(0xfff472b6),
    Color(0xff818cf8),
    Color(0xff2dd4bf),
    Color(0xfffacc15),
  ];
  var hash = 0;
  for (final unit in personId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

class TrainerCalendarEntry {
  const TrainerCalendarEntry({
    required this.id,
    required this.date,
    required this.personId,
    required this.personName,
    required this.title,
    required this.stateLabel,
    this.assessment = false,
    this.muted = false,
    this.completed = false,
    this.onTap,
    this.dragBuilder,
  });
  final String id, personId, personName, title, stateLabel;
  final DateTime date;
  final bool assessment, muted, completed;
  final VoidCallback? onTap;
  final Widget Function(Widget child)? dragBuilder;
}

class TrainerCalendarEntryTile extends StatelessWidget {
  const TrainerCalendarEntryTile({super.key, required this.entry});
  final TrainerCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = trainerCalendarColor(entry.personId);
    final label = '${entry.personName} · ${entry.title} · ${entry.stateLabel}';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: entry.onTap != null,
        child: Material(
          color: color.withValues(alpha: entry.muted ? .05 : .13),
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: entry.onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(7, 5, 5, 5),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.personName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: entry.muted ? .6 : .85,
                              ),
                            ),
                          ),
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: entry.muted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: entry.muted ? .55 : 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      entry.completed
                          ? Icons.check_circle_outline
                          : entry.muted
                          ? Icons.remove_circle_outline
                          : entry.assessment
                          ? Icons.timer_outlined
                          : Icons.event_note_outlined,
                      color: color,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El tablero no consulta ni modifica datos. El portal conserva la autoridad
/// sobre selección, detalle y movimientos mediante sus callbacks existentes.
class TrainerMonthCalendar extends StatelessWidget {
  const TrainerMonthCalendar({
    super.key,
    required this.anchor,
    required this.today,
    required this.entries,
    required this.onSelectDate,
    required this.dropTargetBuilder,
    this.selected,
    this.week = false,
    this.enabled = true,
    this.partial = false,
    this.onSelectAdjacentDate,
  });
  final DateTime anchor, today;
  final DateTime? selected;
  final List<TrainerCalendarEntry> entries;
  final bool week, enabled, partial;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime>? onSelectAdjacentDate;
  final Widget Function(DateTime date, Widget child) dropTargetBuilder;

  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  Future<void> _showDay(
    BuildContext context,
    DateTime date,
    List<TrainerCalendarEntry> rows,
  ) async {
    onSelectDate(date);
    final chosen = await showDialog<TrainerCalendarEntry>(
      context: context,
      builder: (dialogContext) => EntrenaDialog(
        title: Text('Pautas del ${date.day}/${date.month}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.assessment ? Icons.timer_outlined : Icons.event_note,
                  color: trainerCalendarColor(entry.personId),
                ),
                title: Text(entry.personName),
                subtitle: Text('${entry.title}\n${entry.stateLabel}'),
                onTap: entry.onTap == null
                    ? null
                    : () => Navigator.pop(dialogContext, entry),
              ),
            if (partial)
              const Text('Se muestran las entradas cargadas de este día.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (context.mounted) chosen?.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(anchor.year, anchor.month);
    final start = week
        ? DateTime(anchor.year, anchor.month, anchor.day + 1 - anchor.weekday)
        : DateTime(first.year, first.month, first.day + 1 - first.weekday);
    final monthDays = DateTime(anchor.year, anchor.month + 1, 0).day;
    final weeks = week ? 1 : ((first.weekday - 1 + monthDays + 6) ~/ 7);
    final byDate = <DateTime, List<TrainerCalendarEntry>>{};
    for (final entry in entries) {
      final date = DateUtils.dateOnly(entry.date);
      (byDate[date] ??= []).add(entry);
    }
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final entryHeight = 34 * scale + 12;
    final cellHeight = entryHeight * 2 + 72 * scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Color por alumno · Pulsa una sesión para ver sus opciones.',
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.max(constraints.maxWidth, 7 * 126 * scale);
            return SingleChildScrollView(
              key: const ValueKey('agenda-month-horizontal'),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final day in _weekdays)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(day, textAlign: TextAlign.center),
                              ),
                            ),
                        ],
                      ),
                      for (var row = 0; row < weeks; row++)
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var column = 0; column < 7; column++)
                                Expanded(
                                  child: _dayCell(
                                    context,
                                    DateTime(
                                      start.year,
                                      start.month,
                                      start.day + row * 7 + column,
                                    ),
                                    byDate,
                                    entryHeight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime date,
    Map<DateTime, List<TrainerCalendarEntry>> byDate,
    double entryHeight,
  ) {
    final theme = Theme.of(context);
    final inPeriod = week || date.month == anchor.month;
    final rows = inPeriod
        ? byDate[date] ?? const <TrainerCalendarEntry>[]
        : const <TrainerCalendarEntry>[];
    final active = DateUtils.isSameDay(selected, date);
    final isToday = DateUtils.isSameDay(today, date);
    final day = TextButton(
      key: inPeriod ? ValueKey('agenda-day-${date.day}') : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 32),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: isToday ? theme.colorScheme.primary : null,
        foregroundColor: isToday
            ? theme.colorScheme.onPrimary
            : inPeriod
            ? theme.colorScheme.onSurface
            : theme.disabledColor,
      ),
      onPressed: !enabled
          ? null
          : () => inPeriod
                ? onSelectDate(date)
                : onSelectAdjacentDate?.call(date),
      child: Text('${date.day}'),
    );
    final cell = Semantics(
      label:
          '${date.day}/${date.month}/${date.year}, '
          '${rows.where((r) => !r.assessment).length} pautas, '
          '${rows.where((r) => r.assessment).length} pruebas'
          '${partial ? ', recuento parcial' : ''}',
      selected: active,
      child: Container(
        key: ValueKey('agenda-cell-${date.year}-${date.month}-${date.day}'),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: .07)
              : !inPeriod
              ? theme.colorScheme.onSurface.withValues(alpha: .025)
              : null,
          border: Border(
            top: BorderSide(color: theme.dividerColor),
            right: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerRight, child: day),
            for (final entry in rows.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: SizedBox(
                  height: entryHeight,
                  child:
                      entry.dragBuilder?.call(
                        TrainerCalendarEntryTile(
                          key: ValueKey('agenda-month-event-${entry.id}'),
                          entry: entry,
                        ),
                      ) ??
                      TrainerCalendarEntryTile(
                        key: ValueKey('agenda-month-event-${entry.id}'),
                        entry: entry,
                      ),
                ),
              ),
            if (rows.length > 2)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: ValueKey(
                    'agenda-month-more-${date.year}-${date.month}-${date.day}',
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    minimumSize: const Size(44, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: !enabled
                      ? null
                      : () => _showDay(context, date, rows),
                  child: Text(
                    '+${rows.length - 2} más',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    // Los días adyacentes no se han consultado: navegar a su mes antes de
    // permitir una asignación evita presentar una agenda vacía como completa.
    return inPeriod ? dropTargetBuilder(date, cell) : cell;
  }
}
