import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentAppointmentsPage extends StatefulWidget {
  const StudentAppointmentsPage({
    super.key,
    required this.repository,
    required this.userId,
    this.appointmentId,
    this.notices,
  });
  final TrainerAppointmentRepository repository;
  final String userId;
  final String? appointmentId;
  final Stream<void>? notices;
  @override
  State<StudentAppointmentsPage> createState() =>
      _StudentAppointmentsPageState();
}

class _StudentAppointmentsPageState extends State<StudentAppointmentsPage>
    with WidgetsBindingObserver {
  List<TrainerAppointment> _items = [];
  bool _busy = true, _more = false, _history = false;
  int _request = 0;
  String? _error, _saving;
  StreamSubscription<void>? _notices;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _listen();
  }

  void _listen() {
    unawaited(_notices?.cancel());
    _notices = widget.notices?.listen((_) {
      if (mounted && _saving == null) _load();
    });
  }

  @override
  void didUpdateWidget(covariant StudentAppointmentsPage old) {
    super.didUpdateWidget(old);
    if (old.notices != widget.notices) _listen();
    if (old.userId != widget.userId ||
        old.appointmentId != widget.appointmentId ||
        old.repository != widget.repository) {
      _items = [];
      _saving = null;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _saving == null) _load();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notices?.cancel());
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_busy || _items.isEmpty)) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.appointmentId;
      final page = id == null
          ? await widget.repository.list(
              after: more ? _items.last : null,
              history: _history,
            )
          : AppointmentPage([await widget.repository.get(id)]);
      if (!mounted || request != _request) return;
      setState(() {
        _items = more ? [..._items, ...page.items] : page.items;
        _more = page.hasMore;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'No se pudieron cargar las citas. Actualiza para reintentar.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _reminder(TrainerAppointment appointment, int minutes) async {
    final repository = widget.repository, owner = widget.userId;
    setState(() {
      _saving = appointment.id;
      _error = null;
    });
    try {
      final updated = await repository.reminder(appointment, minutes);
      if (!mounted ||
          owner != widget.userId ||
          repository != widget.repository) {
        return;
      }
      setState(
        () => _items = _items
            .map((row) => row.id == updated.id ? updated : row)
            .toList(),
      );
    } catch (_) {
      if (mounted && owner == widget.userId) {
        setState(
          () => _error = 'La cita puede haber cambiado. Actualiza antes de guardar de nuevo.',
        );
      }
    } finally {
      if (mounted && owner == widget.userId) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis citas'),
      actions: [
        IconButton(
          onPressed: _busy || _saving != null ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar citas',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Citas privadas con tus preparadores. Cada una muestra su zona horaria.',
        ),
        if (widget.appointmentId == null)
          Wrap(
            spacing: 8,
            children: [
              for (final history in [false, true])
                ChoiceChip(
                  label: Text(history ? 'Historial y canceladas' : 'Próximas'),
                  selected: _history == history,
                  onSelected: _busy || _saving != null
                      ? null
                      : (_) {
                          setState(() => _history = history);
                          _load();
                        },
                ),
            ],
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_busy && _items.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No tienes citas en esta selección.'),
          ),
        for (final row in _items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        row.cancelled
                            ? Icons.event_busy_outlined
                            : Icons.event_available_outlined,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${row.dateLabel} · ${row.timeLabel} · ${row.durationMinutes} min',
                  ),
                  Text(row.timezone),
                  Text('Con ${row.trainerName}'),
                  if (row.cancelled)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Cita cancelada. Se conserva en tu historial.',
                      ),
                    ),
                  if (row.location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(row.location),
                    if (_locationUri(row.location) case final Uri link)
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          link,
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir enlace de la cita'),
                      ),
                  ],
                  if (row.canRemind) ...[
                    const Divider(height: 28),
                    Text(
                      'Tu recordatorio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (row.suggestedReminder > 0)
                      Text(
                        'Tu preparador sugiere ${_reminderLabel(row.suggestedReminder).toLowerCase()}. Tú decides si activarlo.',
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'appointment-reminder-${row.id}-${row.reminderRevision}',
                      ),
                      initialValue: row.studentReminder,
                      decoration: const InputDecoration(
                        labelText: 'Cuándo avisarme',
                      ),
                      isExpanded: true,
                      items: [
                        for (final value in [0, 30, 1440])
                          DropdownMenuItem(
                            value: value,
                            child: Text(_reminderLabel(value)),
                          ),
                      ],
                      onChanged: _saving != null || _busy
                          ? null
                          : (value) {
                              if (value != null) _reminder(row, value);
                            },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'La notificación requiere tener activados los avisos del preparador y respeta tu horario de descanso.',
                    ),
                  ],
                  if (_saving == row.id) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar más citas'),
          ),
      ],
    ),
  );
}

String _reminderLabel(int minutes) => switch (minutes) {
  30 => '30 minutos antes',
  1440 => 'El día anterior',
  _ => 'Sin recordatorio',
};
Uri? _locationUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          const ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}
