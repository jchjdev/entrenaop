import 'dart:convert';
import 'dart:io';

import 'package:entrenaop_admin/features/programs/domain/pull_up_lab.dart';

void main() {
  final totals = {26: _Totals(), 52: _Totals()};
  final examples = <Map<String, Object?>>[];
  for (final weeks in totals.keys) {
    for (final mark in <int?>[null, 0, 1, 5, 12, 18, 25]) {
      for (final gear in PullGear.values) {
        for (final calendar in PullCalendar.values) {
          for (final response in PullResponse.values) {
            final trace = simulatePullUps(
              startingMark: mark,
              gear: gear,
              calendar: calendar,
              response: response,
              weeks: weeks,
            );
            totals[weeks]!.add(trace, mark, gear, calendar, response);
            if (weeks == 52 &&
                response == PullResponse.favorable &&
                calendar == PullCalendar.combined &&
                ((mark == 0 &&
                        {
                          PullGear.bands,
                          PullGear.rows,
                          PullGear.step,
                        }.contains(gear)) ||
                    (mark == 18 && gear == PullGear.bar))) {
              examples.add({
                'initial': mark,
                'material': gear.name,
                'mark26': trace[25].mark,
                'mark52': trace[51].mark,
                'weeks': [
                  for (final w in trace)
                    if ({1, 2, 6, 13, 26, 52}.contains(w.number) ||
                        w.sessions.any(
                          (s) =>
                              s.decision == PullDecision.test ||
                              s.reason.contains('menos de ayuda'),
                        ))
                      {
                        'week': w.number,
                        'mark': w.mark,
                        'training': [
                          for (final s in w.sessions)
                            {
                              'day': s.day,
                              'dose': s.dose?.label,
                              'action': s.decision.name,
                            },
                        ],
                      },
                ],
              });
            }
          }
        }
      }
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'engine': 'pull_up_lab_v1',
      'assumption':
          'Resultados de entrada ficticios. Agenda de carrera de ejemplo.',
      'totals': {
        for (final entry in totals.entries) '${entry.key}': entry.value.json,
      },
      'examples': examples,
    }),
  );
}

class _Totals {
  int scenarios = 0;
  int weeks = 0;
  int running = 0;
  int pulling = 0;
  int deferred = 0;
  int mixed = 0;
  int atTarget = 0;
  int reachedDuringTrial = 0;
  int firstStrict = 0;
  final actions = <String, int>{};
  final byCalendar = <String, Map<String, int>>{};

  void add(
    List<PullWeek> trace,
    int? initial,
    PullGear gear,
    PullCalendar calendar,
    PullResponse response,
  ) {
    scenarios++;
    if (trace.last.mark == 25) atTarget++;
    if ((initial ?? 0) < 25 && trace.last.mark == 25) reachedDuringTrial++;
    if (initial == 0 && (trace.last.mark ?? 0) > 0) firstStrict++;
    final calendarTotals = byCalendar.putIfAbsent(
      calendar.name,
      () => {'sessions': 0, 'deferred': 0, 'controls': 0},
    );
    int? mark = initial;
    int? lastControl;
    int? lastDay;
    for (final week in trace) {
      weeks++;
      running += week.runs.length;
      pulling += week.sessions.length;
      deferred += week.unplaced;
      calendarTotals.update('sessions', (n) => n + week.sessions.length);
      calendarTotals.update('deferred', (n) => n + week.unplaced);
      final available = switch (calendar) {
        PullCalendar.strength => {1: 45, 3: 45, 5: 45},
        PullCalendar.combined => {1: 50, 3: 45, 5: 50, 7: 45},
        PullCalendar.tight => {1: 32, 3: 30, 5: 18},
      };
      final controls = week.sessions
          .where((s) => s.decision == PullDecision.test)
          .length;
      calendarTotals.update('controls', (n) => n + controls);
      if (week.runs.length != (calendar == PullCalendar.strength ? 0 : 2) ||
          controls > 1 ||
          (controls == 0 && mark != week.mark)) {
        throw StateError(
          'Cambió la carrera o apareció una marca sin control en semana ${week.number}.',
        );
      }
      if (controls == 1) {
        if (mark == 25 ||
            week.sessions.length < 2 ||
            (lastControl != null && week.number - lastControl < 6)) {
          throw StateError(
            'Control sin necesidad, recuperación o práctica ordinaria.',
          );
        }
        lastControl = week.number;
      }
      for (final session in week.sessions) {
        actions.update(session.decision.name, (n) => n + 1, ifAbsent: () => 1);
        final day = week.number * 7 + session.day;
        final runs = week.runs.where((r) => r.day == session.day);
        if (runs.isNotEmpty) mixed++;
        if ((lastDay != null && day - lastDay < 2) ||
            runs.any((r) => r.quality) ||
            runs.fold(session.minutes, (n, r) => n + r.minutes) >
                (available[session.day] ?? 0)) {
          throw StateError(
            'Exposición fuera del hueco o incompatible en semana ${week.number}.',
          );
        }
        if (session.dose case final dose?
            when dose.variant == PullVariant.strict ||
                dose.variant == PullVariant.singles) {
          if ((mark ?? 0) < 2 ||
              !gear.canTest ||
              dose.reps.any((n) => n >= mark!)) {
            throw StateError(
              'Dosis libre incompatible con la última marca observada.',
            );
          }
        }
        if (gear == PullGear.none ||
            (response == PullResponse.interrupted &&
                (week.number >= 13 && week.number <= 15 ||
                    week.number == 31 ||
                    week.number == 32))) {
          throw StateError(
            'Sesión de dominadas durante una interrupción o sin material.',
          );
        }
        lastDay = day;
      }
      mark = week.mark;
    }
  }

  Map<String, Object> get json => {
    'scenarios': scenarios,
    'weeks': weeks,
    'running_sessions': running,
    'pull_sessions': pulling,
    'same_day_as_easy_run': mixed,
    'deferred': deferred,
    'zero_to_first_observed': firstStrict,
    'at_target': atTarget,
    'reached_during_trial': reachedDuringTrial,
    'actions': actions,
    'by_calendar': byCalendar,
  };
}
