import 'package:trainer_access/trainer_access.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_appointments.dart';

import '../domain/coach_workspace_repository.dart';
import 'coach_pages.dart';
import 'coach_planning_pages.dart';
import 'coach_workspace_scope.dart';

const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
// Misma identidad visual que el calendario web; el orden de carga no cambia el color.
const _colors = [
  Color(0xff38bdf8),
  Color(0xffa78bfa),
  Color(0xff34d399),
  Color(0xfffb923c),
  Color(0xfff472b6),
  Color(0xff818cf8),
  Color(0xff2dd4bf),
  Color(0xfffacc15),
];
Color coachStudentColor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _colors[hash % _colors.length];
}

DateTime _shift(DateTime day, int count) =>
    DateTime(day.year, day.month, day.day + count);

enum _AgendaView { day, week, month }

class CoachPlanningAgendaPage extends StatefulWidget {
  const CoachPlanningAgendaPage({super.key});
  @override
  State<CoachPlanningAgendaPage> createState() =>
      _CoachPlanningAgendaPageState();
}

class _CoachPlanningAgendaPageState extends State<CoachPlanningAgendaPage> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  _AgendaView _view = _AgendaView.week;
  List<CoachAssignment> _sessions = [];
  List<TrainerAppointment> _appointments = [];
  bool _initialized = false,
      _busy = false,
      _moreSessions = false,
      _moreAppointments = false,
      _filters = false;
  String? _client, _error;
  final _people = <String, String>{};
  int _generation = 0;
  DateTime get _from => _view == _AgendaView.month
      ? DateTime(_day.year, _day.month)
      : _view == _AgendaView.week
      ? _shift(_day, 1 - _day.weekday)
      : _day;
  DateTime get _to => _view == _AgendaView.month
      ? DateTime(_day.year, _day.month + 1, 0)
      : _view == _AgendaView.week
      ? _shift(_from, 6)
      : _day;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load({
    bool moreSessions = false,
    bool moreAppointments = false,
  }) async {
    final generation = ++_generation,
        scope = CoachWorkspaceScope.of(context),
        from = _from,
        to = _to;
    setState(() {
      _busy = true;
      _error = null;
      if (!moreSessions && !moreAppointments) {
        _sessions = [];
        _appointments = [];
      }
    });
    try {
      final sessions = moreAppointments
          ? _sessions
          : await scope.controller.repository.agenda(
              from,
              to,
              after: moreSessions ? _sessions.lastOrNull : null,
            );
      final appointments = moreSessions
          ? null
          : await scope.planning?.appointments.list(
              from: from,
              to: to,
              after: moreAppointments ? _appointments.lastOrNull : null,
            );
      if (!mounted || generation != _generation) return;
      setState(() {
        _people.addAll({
          for (final s in sessions) s.clientId: s.clientName,
          for (final a in appointments?.items ?? <TrainerAppointment>[])
            a.clientId: a.clientName,
        });
        if (!moreAppointments) {
          _sessions = moreSessions ? [..._sessions, ...sessions] : sessions;
          _moreSessions = sessions.length == 100;
        }
        if (!moreSessions) {
          _appointments = moreAppointments
              ? [..._appointments, ...?appointments?.items]
              : appointments?.items ?? [];
          _moreAppointments = appointments?.hasMore ?? false;
        }
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'No se ha completado la agenda. ${e is Exception ? trainerError(e) : 'Vuelve a intentarlo.'}',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _change(DateTime d, {_AgendaView? view}) {
    setState(() {
      _day = DateUtils.dateOnly(d);
      if (view != null) _view = view;
    });
    _load();
  }

  Future<void> _add() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Añadir el ${coachDate(_day)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Asignar sesión guardada'),
              onTap: () => Navigator.pop(sheet, 'assign'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Crear cita'),
              onTap: () => Navigator.pop(sheet, 'new-appointment'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    final changed = await context.push<bool>(
      coachPlanningRoute(type, day: _day, client: _client),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final planning = CoachWorkspaceScope.of(context).planning;
    final days = _view == _AgendaView.week
        ? List.generate(7, (i) => _shift(_from, i))
        : [_day];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de alumnos'),
        actions: [
          if (planning != null)
            IconButton(
              tooltip: 'Mis sesiones',
              icon: const Icon(Icons.library_books_outlined),
              onPressed: () => context.push('/coach/library'),
            ),
          IconButton(
            tooltip: 'Filtros',
            icon: const Icon(Icons.filter_list),
            onPressed: () => setState(() => _filters = !_filters),
          ),
        ],
      ),
      floatingActionButton: planning == null
          ? null
          : FloatingActionButton(
              tooltip: 'Añadir a la agenda',
              onPressed: _busy ? null : _add,
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in _AgendaView.values)
                  ChoiceChip(
                    label: Text(switch (mode) {
                      _AgendaView.day => 'Día',
                      _AgendaView.week => 'Semana',
                      _AgendaView.month => 'Mes',
                    }),
                    selected: _view == mode,
                    onSelected: (_) => _change(_day, view: mode),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _change(
                    _view == _AgendaView.month
                        ? DateTime(_day.year, _day.month - 1, 1)
                        : _shift(_day, _view == _AgendaView.week ? -7 : -1),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final d = await coachPickDay(context, _day);
                      if (d != null && mounted) _change(d);
                    },
                    child: Text(
                      '${_months[_day.month - 1]} ${_day.year}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Siguiente',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _change(
                    _view == _AgendaView.month
                        ? DateTime(_day.year, _day.month + 1, 1)
                        : _shift(_day, _view == _AgendaView.week ? 7 : 1),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sesiones y citas · color por alumno',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _change(DateTime.now()),
                  child: const Text('Hoy'),
                ),
              ],
            ),
            if (_filters)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: Text(
                      _client == null
                          ? 'Todos los alumnos'
                          : _people[_client] ?? 'Alumno seleccionado',
                    ),
                    onPressed: planning == null
                        ? null
                        : () async {
                            final c = await context.push<TrainerClient>(
                              '/coach/choose-client',
                            );
                            if (c != null && mounted) {
                              setState(() {
                                _client = c.personId;
                                _people[c.personId] = c.name;
                              });
                            }
                          },
                  ),
                  if (_client != null)
                    TextButton(
                      onPressed: () => setState(() => _client = null),
                      child: const Text('Ver todos'),
                    ),
                ],
              ),
            _calendar(),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (_moreSessions || _moreAppointments) ...[
              const Text(
                'Vista parcial: carga el resto para completar el calendario.',
              ),
              if (_moreSessions)
                TextButton(
                  onPressed: _busy ? null : () => _load(moreSessions: true),
                  child: const Text('Cargar más sesiones'),
                ),
              if (_moreAppointments)
                TextButton(
                  onPressed: _busy ? null : () => _load(moreAppointments: true),
                  child: const Text('Cargar más citas'),
                ),
            ],
            for (final day in days.where(
              (day) =>
                  _view != _AgendaView.week ||
                  DateUtils.isSameDay(day, _day) ||
                  _sessions.any(
                    (s) =>
                        DateUtils.isSameDay(s.date, day) &&
                        (_client == null || s.clientId == _client),
                  ) ||
                  _appointments.any(
                    (a) =>
                        DateUtils.isSameDay(a.calendarStart, day) &&
                        (_client == null || a.clientId == _client),
                  ),
            )) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  '${_weekdays[day.weekday - 1]} · ${coachDate(day)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ..._rows(day),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calendar() {
    final start = _view == _AgendaView.month
        ? _shift(
            DateTime(_day.year, _day.month, 1),
            1 - DateTime(_day.year, _day.month, 1).weekday,
          )
        : _shift(_day, 1 - _day.weekday);
    final count = _view == _AgendaView.month
        ? ((DateTime(_day.year, _day.month + 1, 0).day +
                          DateTime(_day.year, _day.month, 1).weekday -
                          2) ~/
                      7 +
                  1) *
              7
        : 7;
    return Column(
      children: [
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Center(
                  child: Text(d, style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
          ],
        ),
        for (var row = 0; row < count ~/ 7; row++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = _shift(start, row * 7 + i);
                      final ids = <String>{
                        ..._sessions
                            .where(
                              (s) =>
                                  DateUtils.isSameDay(s.date, day) &&
                                  (_client == null || s.clientId == _client),
                            )
                            .map((s) => s.clientId),
                        ..._appointments
                            .where(
                              (a) =>
                                  !a.cancelled &&
                                  DateUtils.isSameDay(a.calendarStart, day) &&
                                  (_client == null || a.clientId == _client),
                            )
                            .map((a) => a.clientId),
                      };
                      final selected = DateUtils.isSameDay(day, _day);
                      return Padding(
                        padding: const EdgeInsets.all(2),
                        child: Material(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _change(
                              day,
                              view: _view == _AgendaView.week
                                  ? _AgendaView.day
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    '${day.day}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: day.month == _day.month
                                              ? null
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 5,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (final id in ids.take(3))
                                          Container(
                                            width: 5,
                                            height: 5,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: coachStudentColor(id),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  List<Widget> _rows(DateTime day) {
    final sessions = _sessions
        .where(
          (s) =>
              DateUtils.isSameDay(s.date, day) &&
              (_client == null || s.clientId == _client),
        )
        .toList();
    final appointments =
        _appointments
            .where(
              (a) =>
                  DateUtils.isSameDay(a.calendarStart, day) &&
                  (_client == null || a.clientId == _client),
            )
            .toList()
          ..sort((a, b) => a.calendarStart.compareTo(b.calendarStart));
    if (sessions.isEmpty && appointments.isEmpty && !_busy && _error == null) {
      return [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Sin sesiones ni citas.'),
        ),
      ];
    }
    return [
      for (final a in appointments)
        _event(
          a.clientId,
          a.clientName,
          a.title,
          '${a.timeLabel} · ${a.durationMinutes} min${a.cancelled ? ' · Cancelada' : ''}',
          Icons.event_available,
          onTap: CoachWorkspaceScope.of(context).planning == null
              ? null
              : () async {
                  final changed = await context.push<bool>(
                    '/coach/appointment/${a.id}',
                  );
                  if (changed == true && mounted) _load();
                },
        ),
      for (final s in sessions)
        _event(
          s.clientId,
          s.clientName,
          s.name,
          s.statusLabel,
          Icons.event_note_outlined,
          onTap: () async {
            await context.push(coachAssignmentRoute(s.id));
            if (mounted) _load();
          },
        ),
    ];
  }

  Widget _event(
    String person,
    String name,
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: coachStudentColor(person), width: 4),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: coachStudentColor(person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Alumno' : name,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: coachStudentColor(person)),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
