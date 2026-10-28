import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_appointments.dart';

import 'trainer_month_calendar.dart';

/// Tablero horario de presentación. La página conserva permisos y escrituras.
class TrainerAppointmentWeek extends StatelessWidget {
  const TrainerAppointmentWeek({
    super.key,
    required this.firstDay,
    required this.entries,
    required this.appointments,
    required this.enabled,
    required this.onOpen,
    required this.onMove,
    required this.dragBuilder,
    required this.dayDropBuilder,
  });
  final DateTime firstDay;
  final List<TrainerCalendarEntry> entries;
  final List<TrainerAppointment> appointments;
  final bool enabled;
  final void Function(TrainerAppointment) onOpen;
  final void Function(TrainerAppointment, DateTime, int) onMove;
  final Widget Function(TrainerAppointment, Widget) dragBuilder;
  final Widget Function(DateTime, Widget) dayDropBuilder;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final days = List.generate(
      7,
      (i) => DateTime(firstDay.year, firstDay.month, firstDay.day + i),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, (7 * 154 + 52) * scale);
        final column = (width - 52 * scale) / 7;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Horas de la agenda · ${appointments.firstOrNull?.calendarTimezone ?? 'Europe/Madrid'}',
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 52 * scale),
                    for (final day in days)
                      SizedBox(
                        width: column,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][day.weekday - 1]} ${day.day}/${day.month}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            dayDropBuilder(
                              day,
                              SizedBox(
                                height: 110 * scale,
                                child: ListView(
                                  padding: const EdgeInsets.all(3),
                                  children: [
                                    for (final entry in entries.where(
                                      (e) => DateUtils.isSameDay(e.date, day),
                                    ))
                                      entry.dragBuilder?.call(
                                            TrainerCalendarEntryTile(
                                              entry: entry,
                                            ),
                                          ) ??
                                          TrainerCalendarEntryTile(
                                            entry: entry,
                                          ),
                                    if (!entries.any(
                                      (e) => DateUtils.isSameDay(e.date, day),
                                    ))
                                      const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Text('Sin hora · soltar sesión'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  height: 520,
                  child: _HoursScroll(
                    scale: scale,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 52 * scale,
                          height: 1440 * scale,
                          child: Stack(
                            children: [
                              for (var hour = 0; hour < 24; hour++)
                                Positioned(
                                  top: hour * 60 * scale,
                                  left: 2,
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final day in days)
                          SizedBox(
                            width: column,
                            height: 1440 * scale,
                            child: _day(context, day, column, scale),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _day(BuildContext context, DateTime day, double width, double scale) {
    final segments =
        <
          ({
            TrainerAppointment appointment,
            int start,
            int end,
            int lane,
            int cluster,
          })
        >[];
    final laneEnds = <int>[];
    final clusterLanes = <int, int>{};
    var cluster = 0;
    var clusterEnd = -1;
    final ordered = List<TrainerAppointment>.of(appointments)
      ..sort((a, b) => a.calendarStart.compareTo(b.calendarStart));
    final next = DateTime(day.year, day.month, day.day + 1);
    for (final row in ordered) {
      if (row.calendarStart.isAfter(next) ||
          !row.calendarEnd.isAfter(day) ||
          !row.calendarStart.isBefore(next)) {
        continue;
      }
      final start = row.calendarStart.isBefore(day)
          ? 0
          : row.calendarStart.hour * 60 + row.calendarStart.minute;
      // El servidor convierte ambos extremos: también cubre medianoche y cambios de hora.
      final end = row.calendarEnd.isBefore(next)
          ? row.calendarEnd.hour * 60 + row.calendarEnd.minute
          : 1440;
      if (end <= start) continue;
      if (start >= clusterEnd) {
        cluster++;
        laneEnds.clear();
      }
      clusterEnd = math.max(start >= clusterEnd ? 0 : clusterEnd, end);
      var lane = laneEnds.indexWhere((end) => end <= start);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      clusterLanes[cluster] = laneEnds.length;
      segments.add((
        appointment: row,
        start: start,
        end: end,
        lane: lane,
        cluster: cluster,
      ));
    }
    return Builder(
      builder: (dayContext) => DragTarget<TrainerAppointment>(
        key: ValueKey('appointment-column-drop-${appointmentDay(day)}'),
        onWillAcceptWithDetails: (details) =>
            enabled &&
            details.data.editable &&
            appointments.any((row) => identical(row, details.data)),
        onAcceptWithDetails: (details) {
          // El destino también envuelve las fichas: una cita ya colocada no tapa
          // la zona donde soltar otra y comprobar su solapamiento en el servidor.
          final box = dayContext.findRenderObject() as RenderBox;
          final minute =
              ((box.globalToLocal(details.offset).dy / scale / 30).floor() * 30)
                  .clamp(0, 1410);
          onMove(details.data, day, minute);
        },
        builder: (context, candidates, rejected) => Stack(
          children: [
            for (var minute = 0; minute < 1440; minute += 30)
              Positioned(
                top: minute * scale,
                left: 0,
                right: 0,
                height: 30 * scale,
                child: DragTarget<TrainerAppointment>(
                  key: ValueKey(
                    'appointment-time-drop-${appointmentDay(day)}-$minute',
                  ),
                  onWillAcceptWithDetails: (details) =>
                      enabled &&
                      details.data.editable &&
                      appointments.any((a) => identical(a, details.data)),
                  onAcceptWithDetails: (details) =>
                      onMove(details.data, day, minute),
                  builder: (context, candidates, rejected) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: candidates.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.primary
                                .withValues(alpha: .18),
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: minute % 60 == 0 ? .3 : .1),
                        ),
                        left: BorderSide(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: .25),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final item in segments)
              Positioned(
                top: item.start * scale,
                left: item.lane * width / clusterLanes[item.cluster]! + 2,
                width: width / clusterLanes[item.cluster]! - 4,
                height: (item.end - item.start) * scale,
                child: dragBuilder(
                  item.appointment,
                  Tooltip(
                    message:
                        '${item.appointment.clientName} · ${item.appointment.title} · ${item.appointment.timeLabel} · ${item.appointment.durationMinutes} min · ${item.appointment.timezone}',
                    child: Material(
                      color: trainerCalendarColor(item.appointment.clientId)
                          .withValues(
                            alpha: item.appointment.cancelled ? .08 : .2,
                          ),
                      borderRadius: BorderRadius.circular(4),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey(
                          'appointment-hour-${item.appointment.id}-${appointmentDay(day)}',
                        ),
                        onTap: () => onOpen(item.appointment),
                        child: Semantics(
                          label:
                              'Cita con ${item.appointment.clientName}: ${item.appointment.title}',
                          button: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: trainerCalendarColor(
                                    item.appointment.clientId,
                                  ),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  constraints.maxHeight < 14 * scale
                                  ? const SizedBox.shrink()
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        '${item.appointment.calendarStart.hour.toString().padLeft(2, '0')}:${item.appointment.calendarStart.minute.toString().padLeft(2, '0')} · ${item.appointment.clientName}${constraints.maxHeight >= 30 * scale ? '\n${item.appointment.title}' : ' · ${item.appointment.title}'}',
                                        maxLines:
                                            constraints.maxHeight >= 30 * scale
                                            ? 2
                                            : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.2,
                                          decoration: item.appointment.cancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HoursScroll extends StatefulWidget {
  const _HoursScroll({required this.child, required this.scale});
  final Widget child;
  final double scale;
  @override
  State<_HoursScroll> createState() => _HoursScrollState();
}

class _HoursScrollState extends State<_HoursScroll> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: 8 * 60 * widget.scale,
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(controller: _scroll, child: widget.child),
  );
}
