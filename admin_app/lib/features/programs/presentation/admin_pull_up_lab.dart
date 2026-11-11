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
  PullGear _gear = PullGear.bandsAndRows;
  PullCalendar _calendar = PullCalendar.combined;
  PullResponse _response = PullResponse.favorable;

  (int, int, PullGear, PullCalendar, PullResponse)? _simulationKey;
  late List<PullWeek> _trace;
  late List<PullWeek> _candidate;

  void _refreshSimulation() {
    final key = (_mark, _weeks, _gear, _calendar, _response);
    if (_simulationKey == key) return;
    _trace = simulatePullUps(
      startingMark: _mark < 0 ? null : _mark,
      gear: _gear,
      calendar: _calendar,
      response: _response,
      weeks: _weeks,
    );
    _candidate = simulatePullUps(
      startingMark: _mark < 0 ? null : _mark,
      gear: _gear,
      calendar: _calendar,
      response: _response,
      weeks: _weeks,
      approach: PullApproach.australian,
    );
    // Consultar otra semana no cambia los parámetros ni recalcula ambos brazos.
    _simulationKey = key;
  }

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
    _refreshSimulation();
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
        const SizedBox(height: 8),
        const Text(
          'Compara las dos propuestas con el mismo nivel, material, agenda y respuesta. '
          'La segunda ensaya un circuito supino de 5 normales + 5 cerradas + 5 s de hold '
          'y otro de 5 abiertas + 5 normales + 5 cerradas + 5 s de hold. '
          'Cada circuito empieza con una calibración propia. Desde cinco dominadas estrictas '
          'se retiran las australianas automáticas en el siguiente cálculo semanal. La programación de otras '
          'variantes avanzadas sigue pendiente de revisión.',
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
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 780
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _weekView(PullApproach.current, _trace),
                ),
                SizedBox(
                  width: width,
                  child: _weekView(PullApproach.australian, _candidate),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const ExpansionTile(
          key: PageStorageKey('pull-up-lab-evidence'),
          title: Text('Qué respalda la ciencia'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'El remo invertido permite practicar tirón con un montaje graduable. '
              'Youdas y colaboradores (2016) midieron activación muscular con agarres prono y supino. '
              'Ese estudio no probó esta secuencia de anchos ni su transferencia a una marca de dominadas. '
              'Los 5 s, la dosis inicial y los dos días comparables son parámetros de este ensayo. '
              'Las simulaciones comprueban las decisiones y la agenda. La eficacia necesita resultados reales.',
            ),
          ],
        ),
        const ExpansionTile(
          key: PageStorageKey('pull-up-lab-preparation'),
          title: Text('Cómo usar estas estrategias en una preparación'),
          childrenPadding: EdgeInsets.all(16),
          children: [
            Text(
              'Aquí puedes comparar sesiones y decisiones. En Programas, abre una versión en borrador '
              'y entra en «Cómo se prepara cada prueba» para configurar la tarea y sus condiciones. '
              'La estrategia disponible elige trabajo y dosis con los registros del deportista. '
              'El coordinador organiza el conjunto con carrera, prioridades y minutos disponibles. '
              'La propuesta de australianas está en fase de laboratorio. Su incorporación requiere '
              'validar primero el registro y la publicación de la siguiente semana en desarrollo.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _weekView(PullApproach approach, List<PullWeek> trace) {
    final week = trace[_selectedWeek - 1];
    final reference = _selectedWeek == 1
        ? (_mark < 0 ? null : _mark)
        : trace[_selectedWeek - 2].mark;
    final controls = trace
        .expand((w) => w.sessions)
        .where((s) => s.decision == PullDecision.test)
        .length;
    final deferred = trace.fold(0, (sum, w) => sum + w.unplaced);
    final supports = trace
        .expand((w) => w.sessions)
        .where((s) => s.supportDose != null)
        .length;
    final deferredSupports = trace.fold(
      0,
      (sum, w) => sum + w.deferredSupports,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approach.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('$controls controles · $deferred exposiciones aplazadas'),
            if (approach == PullApproach.australian)
              Text(
                '$supports circuitos de apoyo colocados · $deferredSupports aplazados por agenda',
              ),
            Text(
              'Última marca del guion completo ${trace.last.mark ?? 'sin medir'}',
            ),
            Text(
              'Referencia al calcular esta semana ${reference ?? 'sin medir'} estrictas',
            ),
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
              for (final session in week.sessions.where(
                (s) => s.day == day,
              )) ...[
                Text(
                  '${session.dose?.label ?? 'Control de dominadas estrictas'} · ${session.minutes} min',
                ),
                if (session.dose case final dose?
                    when dose.reps.length > 1 && !dose.isCircuit)
                  Text('Pausa entre series ${dose.restSeconds} s'),
                if (session.dose?.isCircuit ?? false)
                  const Text(
                    'Un circuito. Hasta 10 s para recolocar manos entre anchos.',
                  ),
                Text(session.reason),
                if (session.supportDose case final support?) ...[
                  Text('Apoyo al final · ${support.label}'),
                  const Text(
                    'Pausa previa 120 s. Un circuito. Hasta 10 s para recolocar manos entre anchos.',
                  ),
                ],
                if (session.supportReason.isNotEmpty)
                  Text(session.supportReason),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
