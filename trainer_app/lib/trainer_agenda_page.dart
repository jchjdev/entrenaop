import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';

String agendaDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TrainerAgendaItem {
  TrainerAgendaItem.fromJson(Map<String, dynamic> row)
    : assignment = TrainerAssignment.fromJson(row),
      clientId = row['client_id'] as String,
      clientName = row['client_name'] as String;
  final TrainerAssignment assignment;
  final String clientId, clientName;
}

abstract class TrainerAgendaRepository {
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
  });
}

class SupabaseTrainerAgendaRepository implements TrainerAgendaRepository {
  const SupabaseTrainerAgendaRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
  }) async {
    _identity();
    final rows = await client.rpc(
      'list_trainer_agenda',
      params: {
        'p_from': agendaDate(from),
        'p_to': agendaDate(to),
        'p_after_date': after == null
            ? null
            : agendaDate(after.assignment.date),
        'p_after_id': after?.assignment.id,
      },
    );
    _identity();
    return (rows as List)
        .map(
          (row) =>
              TrainerAgendaItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }
}

class TrainerAgendaPage extends StatefulWidget {
  const TrainerAgendaPage({super.key, required this.repository, this.now});
  final TrainerAgendaRepository repository;
  final DateTime? now;
  @override
  State<TrainerAgendaPage> createState() => _TrainerAgendaPageState();
}

class _TrainerAgendaPageState extends State<TrainerAgendaPage> {
  late DateTime _month = DateTime(
    (widget.now ?? DateTime.now()).year,
    (widget.now ?? DateTime.now()).month,
  );
  DateTime? _selected;
  List<TrainerAgendaItem> _items = [];
  bool _busy = true, _more = false, _calendar = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.range(
        _month,
        DateTime(_month.year, _month.month + 1, 0),
        after: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 100;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _move(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selected = null;
      _items = [];
    });
    _load();
  }

  String get _monthName => [
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
  ][_month.month - 1];
  @override
  Widget build(BuildContext context) {
    final visible = _selected == null
        ? _items
        : _items
              .where((i) => DateUtils.isSameDay(i.assignment.date, _selected))
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda profesional'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Planificación y resultados de tus alumnos. Aquí se muestran las pautas de tu servicio; cada alumno conserva también su agenda personal.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => _move(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mes anterior',
                  ),
                  Text(
                    '$_monthName ${_month.year}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _move(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Mes siguiente',
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            final today = widget.now ?? DateTime.now();
                            setState(() {
                              _month = DateTime(today.year, today.month);
                              _selected = DateUtils.dateOnly(today);
                              _items = [];
                            });
                            _load();
                          },
                    child: const Text('Hoy'),
                  ),
                  FilterChip(
                    label: const Text('Calendario'),
                    selected: _calendar,
                    onSelected: (value) => setState(() => _calendar = value),
                  ),
                  if (_selected != null)
                    TextButton(
                      onPressed: () => setState(() => _selected = null),
                      child: const Text('Ver todo el mes'),
                    ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Reintentar'),
                ),
              ],
              if (_more)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Hay más pautas por cargar. Los recuentos del calendario son parciales.',
                  ),
                ),
              if (_calendar) _grid(),
              const SizedBox(height: 16),
              Text(
                _selected == null
                    ? 'Pautas del mes'
                    : 'Pautas del ${_selected!.day}/${_selected!.month}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!_busy && visible.isEmpty && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _more
                        ? 'No hay pautas en esta selección entre las cargadas.'
                        : 'No hay pautas en esta selección.',
                  ),
                ),
              for (final row in visible)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row.clientName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(row.assignment.name),
                        Text(
                          '${row.assignment.date.day}/${row.assignment.date.month} · ${row.assignment.statusLabel} · v${row.assignment.version}',
                        ),
                        if (row.assignment.note?.isNotEmpty == true)
                          Text(row.assignment.note!),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => context.go(
                                '/clients/${row.clientId}/workouts',
                              ),
                              child: const Text('Planificación del alumno'),
                            ),
                            if (row.assignment.executionId != null)
                              FilledButton.tonal(
                                onPressed: () => context.push(
                                  '/clients/${row.clientId}/workouts/${row.assignment.id}/result',
                                ),
                                child: const Text('Ver resultados'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_more)
                OutlinedButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Cargar más pautas del mes'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final leading = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(child: Center(child: Text(label))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 21
                ? 82
                : 64,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, day);
            final count = _items
                .where(
                  (i) =>
                      DateUtils.isSameDay(i.assignment.date, date) &&
                      i.assignment.status != 'cancelled',
                )
                .length;
            final selected = DateUtils.isSameDay(_selected, date);
            return Semantics(
              label:
                  '$day de $_monthName, $count pautas${_more ? ', recuento parcial' : ''}',
              selected: selected,
              child: TextButton(
                key: ValueKey('agenda-day-$day'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                onPressed: () => setState(() => _selected = date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: const TextStyle(fontSize: 14)),
                    if (count > 0)
                      Text('$count', style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
