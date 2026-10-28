import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:uuid/uuid.dart';

import 'trainer_agenda_client_picker.dart';

Future<bool> confirmAppointmentOverlap(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => EntrenaDialog(
        title: const Text('Citas coincidentes'),
        content: const Text(
          'Ya tienes otra cita en ese horario. ¿Quieres mantener las dos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Mantener ambas'),
          ),
        ],
      ),
    ) ??
    false;

class TrainerAppointmentDialog extends StatefulWidget {
  const TrainerAppointmentDialog({
    super.key,
    required this.repository,
    required this.clients,
    required this.initialDay,
    this.initial,
    this.clientId,
  });
  final TrainerAppointmentRepository repository;
  final TrainerRepository clients;
  final TrainerAppointment? initial;
  final DateTime initialDay;
  final String? clientId;
  @override
  State<TrainerAppointmentDialog> createState() =>
      _TrainerAppointmentDialogState();
}

class _TrainerAppointmentDialogState extends State<TrainerAppointmentDialog> {
  final _form = GlobalKey<FormState>();
  late final _id = widget.initial?.id ?? const Uuid().v4();
  late final _title = TextEditingController(
    text: widget.initial?.title ?? 'Revisión de la preparación',
  );
  late final _location = TextEditingController(
    text: widget.initial?.location ?? '',
  );
  late final _duration = TextEditingController(
    text: '${widget.initial?.durationMinutes ?? 30}',
  );
  late final _timezone = TextEditingController(
    text: widget.initial?.timezone ?? 'Europe/Madrid',
  );
  late DateTime _day;
  late int _minute;
  late int _suggestion = widget.initial?.suggestedReminder ?? 0;
  TrainerClient? _client;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateUtils.dateOnly(widget.initial?.localStart ?? widget.initialDay);
    if (widget.initial == null && _day.isBefore(DateUtils.dateOnly(now))) {
      _day = DateUtils.dateOnly(now);
    }
    _minute =
        widget.initial?.minute ??
        (DateUtils.isSameDay(_day, now)
            ? ((now.hour * 60 + now.minute + 30) ~/ 30) * 30
            : 540);
    if (_minute >= 1440) {
      _day = DateTime(_day.year, _day.month, _day.day + 1);
      _minute = 540;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _duration.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Future<void> _chooseClient() async {
    final client = await showDialog<TrainerClient>(
      context: context,
      builder: (_) => TrainerAgendaClientPicker(
        repository: widget.clients,
        selectedId: widget.clientId,
        forAppointment: true,
      ),
    );
    if (mounted && client != null) setState(() => _client = client);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final relation = widget.initial?.relationId ?? _client?.activeRelationId;
    if (relation == null) {
      setState(() => _error = 'Elige un alumno con servicio activo.');
      return;
    }
    final draft = AppointmentDraft(
      id: _id,
      relationId: relation,
      title: _title.text,
      day: _day,
      minute: _minute,
      durationMinutes: int.parse(_duration.text),
      timezone: _timezone.text.trim(),
      revision: widget.initial?.revision ?? 0,
      location: _location.text,
      suggestedReminder: _suggestion,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var result = await widget.repository.save(draft);
      if (!mounted) return;
      if (result.requiresConfirmation) {
        if (!await confirmAppointmentOverlap(context)) return;
        if (!mounted) return;
        result = await widget.repository.save(draft, allowOverlap: true);
      }
      if (result.appointment == null) {
        throw StateError('No se ha confirmado la cita.');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Revisa la fecha, la zona horaria o si la cita ha cambiado. Cierra y actualiza antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: EntrenaDialog(
      title: Text(widget.initial == null ? 'Nueva cita' : 'Editar cita'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  widget.initial?.clientName ??
                      _client?.name ??
                      'Elige un alumno',
                ),
                trailing: widget.initial == null
                    ? TextButton(
                        onPressed: _busy ? null : _chooseClient,
                        child: const Text('Elegir'),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Motivo'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe el motivo.' : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final day = await showDatePicker(
                              context: context,
                              initialDate: _day,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(
                                DateTime.now().year + 3,
                                12,
                                31,
                              ),
                            );
                            if (mounted && day != null) {
                              setState(() => _day = day);
                            }
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('${_day.day}/${_day.month}/${_day.year}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _minute ~/ 60,
                                minute: _minute % 60,
                              ),
                            );
                            if (mounted && time != null) {
                              setState(
                                () => _minute = time.hour * 60 + time.minute,
                              );
                            }
                          },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      '${(_minute ~/ 60).toString().padLeft(2, '0')}:${(_minute % 60).toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _duration,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duración (min)'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 15 || n > 720
                      ? 'Entre 15 y 720 minutos.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timezone,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Zona horaria'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Indica la zona.' : null,
              ),
              const SizedBox(height: 6),
              const Text(
                'Península: Europe/Madrid · Canarias: Atlantic/Canary. Se conserva esta zona aunque el alumno viaje.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _location,
                enabled: !_busy,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Lugar o enlace'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _suggestion,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recordatorio sugerido',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sin sugerencia')),
                  DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
                  DropdownMenuItem(value: 1440, child: Text('El día anterior')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _suggestion = v ?? 0),
              ),
              const SizedBox(height: 8),
              const Text(
                'El alumno decide si activa el recordatorio. Los cambios de la cita generan avisos agrupados.',
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Guardar cita'),
        ),
      ],
    ),
  );
}
