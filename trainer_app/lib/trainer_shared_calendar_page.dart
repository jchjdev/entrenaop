import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:workout_core/workout_template_model.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

/// Vista por alumno: no reutiliza la agenda operativa ni sus acciones de edición.
class TrainerSharedCalendarPage extends StatefulWidget {
  const TrainerSharedCalendarPage({
    super.key,
    required this.repository,
    required this.clientId,
  });
  final TrainerSharedCalendarRepository repository;
  final String clientId;
  @override
  State<TrainerSharedCalendarPage> createState() =>
      _TrainerSharedCalendarPageState();
}

class _TrainerSharedCalendarPageState extends State<TrainerSharedCalendarPage>
    with WidgetsBindingObserver {
  late DateTime _from;
  SharedCalendarPage? _page;
  final _entries = <SharedCalendarEntry>[];
  bool _busy = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final today = DateUtils.dateOnly(DateTime.now());
    _from = today.subtract(Duration(days: today.weekday - 1));
    _load();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrainerSharedCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _entries.clear();
        _page = null;
      }
    });
    try {
      final value = await widget.repository.calendar(
        widget.clientId,
        _from,
        _from.add(const Duration(days: 6)),
        after: more && _entries.isNotEmpty ? _entries.last : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = value;
        if (!value.shared) _entries.clear();
        _entries.addAll(value.entries);
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _entries.clear();
          _page = null;
          _error = trainerError(error);
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _open(SharedCalendarEntry entry) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await widget.repository.workout(widget.clientId, entry.id);
      if (!mounted || request != _request) return;
      final template = WorkoutTemplateModel.fromJson(json);
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: ProfessionalWorkspaceScope.pageConstraints(
              context,
              maxWidth: 760,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.name} · Solo lectura',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar pauta',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: WorkoutTemplateContent(template: template),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && request == _request) await _load();
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _entries.clear();
          _page = null;
          _error = trainerError(error);
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  void _week(int delta) {
    _from = _from.add(Duration(days: delta * 7));
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendario compartido'),
      actions: [
        IconButton(
          tooltip: 'Actualizar calendario',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: ProfessionalWorkspaceScope.pageConstraints(
          context,
          maxWidth: 1000,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Consulta las pautas para coordinar la carga. Cada preparador modifica únicamente sus propias asignaciones. Las coincidencias no sustituyen sesiones automáticamente.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  onPressed: _busy ? null : () => _week(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${trainerDate(_from)} – ${trainerDate(_from.add(const Duration(days: 6)))}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  onPressed: _busy ? null : () => _week(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_page?.shared == false)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'El alumno todavía no comparte su calendario. Puede activarlo en Preparador → Vínculos → Compartir mi calendario con mis preparadores.',
                  ),
                ),
              ),
            if (_page?.shared == true) ...[
              Text('Preparadores activos: ${_page!.coaches.join(', ')}'),
              if (_entries.isEmpty && !_busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay sesiones en esta semana.'),
                ),
              for (var day = 0; day < 7; day++) ...[
                if (_entries.any(
                  (e) => DateUtils.isSameDay(
                    e.date,
                    _from.add(Duration(days: day)),
                  ),
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Text(
                      trainerDate(_from.add(Duration(days: day))),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                for (final entry in _entries.where(
                  (e) => DateUtils.isSameDay(
                    e.date,
                    _from.add(Duration(days: day)),
                  ),
                ))
                  Card(
                    child: ListTile(
                      leading: Icon(
                        entry.running
                            ? Icons.directions_run
                            : Icons.fitness_center,
                      ),
                      title: Text(entry.name),
                      subtitle: Text(
                        [
                          if (entry.time != null) entry.time!.substring(0, 5),
                          entry.source == 'coach'
                              ? '${entry.trainerName}${entry.own ? ' (tú)' : ''}'
                              : entry.source == 'user'
                              ? 'Planificación personal'
                              : 'EntrenaOP',
                          if (entry.minutes != null) '${entry.minutes} min',
                          switch (entry.status) {
                            'planned' => 'Pendiente',
                            'in_progress' => 'En curso',
                            'completed' => 'Realizada',
                            'cancelled' => 'Retirada',
                            'skipped' => 'Omitida',
                            'abandoned' => 'Abandonada',
                            _ => entry.status,
                          },
                          if (!entry.relationActive) 'Vínculo finalizado',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.visibility_outlined),
                      onTap: _busy ? null : () => _open(entry),
                    ),
                  ),
              ],
              if (_page!.hasMore)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Ver más sesiones de esta semana'),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
