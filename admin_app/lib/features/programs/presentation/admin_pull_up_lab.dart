import 'package:flutter/material.dart';

import '../domain/pull_up_lab.dart';

class AdminPullUpLab extends StatefulWidget {
  const AdminPullUpLab({super.key});

  @override
  State<AdminPullUpLab> createState() => _AdminPullUpLabState();
}

class _AdminPullUpLabState extends State<AdminPullUpLab> {
  static const _marks = [-1, 0, 1, 5, 12, 18, 25];
  int _mark = 0;
  int _weeks = 26;
  int _selectedWeek = 1;
  PullGear _gear = PullGear.bands;
  PullCalendar _calendar = PullCalendar.combined;
  PullResponse _response = PullResponse.favorable;

  Widget _choice<T>(
    String label,
    T value,
    Iterable<T> options,
    String Function(T) name,
    ValueChanged<T> change,
  ) => SizedBox(
    width: 250,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: [
            for (final item in options)
              DropdownMenuItem(
                value: item,
                child: Text(name(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (next) => setState(() {
            if (next != null) change(next);
          }),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final trace = simulatePullUps(
      startingMark: _mark < 0 ? null : _mark,
      gear: _gear,
      calendar: _calendar,
      response: _response,
      weeks: _weeks,
    );
    final week = trace[_selectedWeek - 1];
    final controls = trace
        .expand((w) => w.sessions)
        .where((s) => s.decision == PullDecision.test)
        .length;
    final deferred = trace.fold(0, (sum, w) => sum + w.unplaced);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dominadas estrictas · meta de 25',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Ensayo de decisiones con carrera de ejemplo y resultados ficticios. Las marcas del guion solo entran al realizar un control.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _choice(
              'Marca inicial',
              _mark,
              _marks,
              (n) => n < 0 ? 'Sin medir' : '$n válidas',
              (n) => _mark = n,
            ),
            _choice(
              'Material',
              _gear,
              PullGear.values,
              (g) => g.label,
              (g) => _gear = g,
            ),
            _choice(
              'Agenda',
              _calendar,
              PullCalendar.values,
              (c) => c.label,
              (c) => _calendar = c,
            ),
            _choice(
              'Respuesta del guion',
              _response,
              PullResponse.values,
              (r) => r.label,
              (r) => _response = r,
            ),
            _choice(
              'Horizonte',
              _weeks,
              [26, 52],
              (n) => n == 26 ? '6 meses · 26 semanas' : '12 meses · 52 semanas',
              (n) {
                _weeks = n;
                if (_selectedWeek > n) _selectedWeek = n;
              },
            ),
            _choice(
              'Semana',
              _selectedWeek,
              List.generate(_weeks, (i) => i + 1),
              (n) => 'Semana $n',
              (n) => _selectedWeek = n,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '$controls controles · $deferred exposiciones aplazadas · última marca observada en el guion: ${trace.last.mark ?? 'sin medir'}',
        ),
        const SizedBox(height: 8),
        if (week.note.isNotEmpty) Text(week.note),
        for (final day in {
          ...week.runs.map((r) => r.day),
          ...week.sessions.map((s) => s.day),
        }.toList()..sort()) ...[
          const Divider(),
          Text(
            const [
              'Lunes',
              'Martes',
              'Miércoles',
              'Jueves',
              'Viernes',
              'Sábado',
              'Domingo',
            ][day - 1],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final run in week.runs.where((r) => r.day == day))
            Text('${run.name} · ${run.minutes} min'),
          for (final session in week.sessions.where((s) => s.day == day)) ...[
            Text(
              '${session.dose?.label ?? 'Control de dominadas estrictas'} · ${session.minutes} min',
            ),
            if (session.dose case final dose? when dose.reps.length > 1)
              Text('Pausa entre series: ${dose.restSeconds} s'),
            Text(session.reason),
          ],
        ],
      ],
    );
  }
}
