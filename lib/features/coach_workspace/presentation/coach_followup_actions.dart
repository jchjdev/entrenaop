import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

import 'coach_mobile_style.dart';
import 'coach_pages.dart';
import 'coach_planning_pages.dart';
import 'coach_workspace_scope.dart';

class CoachAppointmentPage extends StatefulWidget {
  const CoachAppointmentPage({super.key, this.id, this.clientId, this.day});
  final String? id, clientId;
  final DateTime? day;
  @override
  State<CoachAppointmentPage> createState() => _CoachAppointmentPageState();
}

class _CoachAppointmentPageState extends State<CoachAppointmentPage>
    with CoachWriteState<CoachAppointmentPage> {
  final _title = TextEditingController(), _location = TextEditingController();
  TrainerClient? _client;
  TrainerAppointment? _previous;
  late DateTime _day = DateUtils.dateOnly(widget.day ?? DateTime.now());
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60, _reminder = 0;
  String _timezone = 'Europe/Madrid';
  bool _initialized = false, _loading = true, _cancelling = false;
  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    final scope = CoachWorkspaceScope.of(context);
    try {
      final a = widget.id == null
          ? null
          : await scope.planning!.appointments.get(widget.id!);
      final clientId = a?.clientId ?? widget.clientId;
      final c = clientId == null
          ? null
          : (await scope.controller.repository.client(clientId)).client;
      if (!mounted) return;
      setState(() {
        _client = c;
        _previous = a;
        if (a != null) {
          _title.text = a.title;
          _location.text = a.location;
          _day = DateUtils.dateOnly(a.localStart);
          _time = TimeOfDay(
            hour: a.localStart.hour,
            minute: a.localStart.minute,
          );
          _duration = a.durationMinutes;
          _reminder = a.suggestedReminder;
          _timezone = a.timezone;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          error = trainerError(e);
        });
      }
    }
  }

  Future<void> _cancel(String id) async {
    final repo = CoachWorkspaceScope.of(context).planning!.appointments;
    try {
      await repo.cancel(_previous!);
    } catch (e) {
      final latest = await repo.get(_previous!.id);
      if (!latest.cancelled) rethrow;
    }
  }

  Future<void> _save(String id) async {
    final repo = CoachWorkspaceScope.of(context).planning!.appointments;
    final draft = AppointmentDraft(
      id: _previous?.id ?? id,
      relationId: _previous?.relationId ?? _client!.activeRelationId!,
      revision: _previous?.revision ?? 0,
      title: _title.text,
      day: _day,
      minute: _time.hour * 60 + _time.minute,
      durationMinutes: _duration,
      timezone: _timezone,
      location: _location.text,
      suggestedReminder: _reminder,
    );
    final result = await repo.save(draft);
    if (result.requiresConfirmation) {
      if (!mounted ||
          !await coachConfirm(
            context,
            'Coincidencia de citas',
            'Hay otra cita en ese horario. ¿Quieres mantener ambas?',
            action: 'Mantener ambas',
          )) {
        throw StateError('No se ha confirmado la coincidencia.');
      }
      final confirmed = await repo.save(draft, allowOverlap: true);
      if (confirmed.appointment == null) {
        throw StateError('Actualiza la agenda para comprobar el estado.');
      }
    } else if (result.appointment == null) {
      throw StateError('No se ha confirmado la cita.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable =
        (_previous == null || _previous!.editable) &&
        !(_previous?.cancelled ?? false);
    return form(
      widget.id == null ? 'Nueva cita' : 'Cita con el alumno',
      [
        if (_loading) const LinearProgressIndicator(),
        CoachNavigationCard(
          title: _client?.name ?? 'Elegir alumno',
          subtitle: _previous?.status == 'cancelled'
              ? 'Cita cancelada'
              : 'Cita privada del servicio',
          icon: Icons.person_outline,
          onTap: frozen || _previous != null
              ? null
              : () async {
                  final c = await context.push<TrainerClient>(
                    '/coach/choose-client',
                  );
                  if (c != null && mounted) {
                    setState(() {
                      _client = c;
                      dirty = true;
                    });
                  }
                },
        ),
        TextField(
          controller: _title,
          enabled: editable && !frozen,
          maxLength: 120,
          onChanged: (_) => setState(() => dirty = true),
          decoration: const InputDecoration(labelText: 'Motivo de la cita'),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(coachDate(_day)),
              onPressed: !editable || frozen
                  ? null
                  : () async {
                      final d = await coachPickDay(context, _day);
                      if (d != null && mounted) {
                        setState(() {
                          _day = d;
                          dirty = true;
                        });
                      }
                    },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(_time.format(context)),
              onPressed: !editable || frozen
                  ? null
                  : () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null && mounted) {
                        setState(() {
                          _time = t;
                          dirty = true;
                        });
                      }
                    },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Hora de la cita: $_timezone'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _timezone,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Zona horaria'),
          items: {
            _timezone,
            'Europe/Madrid',
            'Atlantic/Canary',
            'UTC',
          }.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
          onChanged: editable && !frozen
              ? (v) => setState(() {
                  _timezone = v!;
                  dirty = true;
                })
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _duration,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Duración'),
          items: {_duration, 15, 30, 45, 60, 90, 120}
              .map((v) => DropdownMenuItem(value: v, child: Text('$v minutos')))
              .toList(),
          onChanged: editable && !frozen
              ? (v) => setState(() {
                  _duration = v!;
                  dirty = true;
                })
              : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          enabled: editable && !frozen,
          maxLength: 500,
          maxLines: 2,
          onChanged: (_) => dirty = true,
          decoration: const InputDecoration(
            labelText: 'Lugar o enlace (opcional)',
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: _reminder,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Sugerir recordatorio al alumno',
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Sin sugerencia')),
            DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
            DropdownMenuItem(value: 1440, child: Text('El día anterior')),
          ],
          onChanged: editable && !frozen
              ? (v) => setState(() {
                  _reminder = v!;
                  dirty = true;
                })
              : null,
        ),
        const SizedBox(height: 12),
        const Text(
          'El alumno recibe el aviso de cambio según sus preferencias. Elige si acepta el recordatorio sugerido.',
        ),
        if (_previous != null && editable)
          TextButton.icon(
            icon: const Icon(Icons.event_busy),
            label: const Text('Cancelar cita'),
            onPressed: busy || frozen
                ? null
                : () async {
                    if (await coachConfirm(
                      context,
                      'Cancelar cita',
                      'La cita quedará cancelada y se avisará al alumno.',
                      action: 'Cancelar cita',
                    )) {
                      _cancelling = true;
                      write(_cancel);
                    }
                  },
          ),
      ],
      label: 'Guardar cita',
      save:
          _loading ||
              !editable ||
              _client?.active != true ||
              _title.text.trim().isEmpty
          ? null
          : () => write(_cancelling ? _cancel : _save),
    );
  }
}

class CoachFormsPage extends StatefulWidget {
  const CoachFormsPage({super.key, required this.clientId});
  final String clientId;
  @override
  State<CoachFormsPage> createState() => _CoachFormsPageState();
}

class _CoachFormsPageState extends State<CoachFormsPage> {
  int _revision = 0;
  @override
  Widget build(BuildContext context) {
    final p = CoachWorkspaceScope.of(context).planning!;
    return CoachPagedList<TrainerFormAssignment>(
      key: ValueKey(_revision),
      title: 'Formularios del alumno',
      pageSize: 50,
      load: (before) => p.formAssignments(widget.clientId, before: before),
      header: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FilledButton.icon(
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar formulario guardado'),
          onPressed: () async {
            final changed = await context.push<bool>(
              coachPlanningRoute('send-form', client: widget.clientId),
            );
            if (changed == true && context.mounted) {
              setState(() => _revision++);
            }
          },
        ),
      ),
      row: (context, a) => CoachNavigationCard(
        title: a.form.title,
        subtitle: '${a.statusLabel} · ${coachDate(a.dueDate)}',
        icon: Icons.assignment_outlined,
        onTap: () => context.push('/coach/form/${a.id}'),
      ),
    );
  }
}

String coachFormAnswer(TrainerFormAssignment a, TrainerFollowupQuestion q) {
  final value = a.answers?[q.id];
  if (value == null) return 'Sin respuesta';
  String option(Object? v) =>
      q.options.where((o) => o.id == v).firstOrNull?.label ?? '$v';
  if (q.type == TrainerFollowupQuestionType.singleChoice) return option(value);
  if (q.type == TrainerFollowupQuestionType.multipleChoice && value is List) {
    return value.map((v) => option(v)).join(', ');
  }
  if (value is bool) return value ? 'Sí' : 'No';
  return '$value';
}

class CoachSendFormPage extends StatefulWidget {
  const CoachSendFormPage({super.key, required this.clientId});
  final String clientId;
  @override
  State<CoachSendFormPage> createState() => _CoachSendFormPageState();
}

class _CoachSendFormPageState extends State<CoachSendFormPage>
    with CoachWriteState<CoachSendFormPage> {
  TrainerClient? _client;
  List<TrainerFollowupFormVersion> _forms = [];
  TrainerFollowupFormVersion? _selected;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _initialized = false, _loading = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    final scope = CoachWorkspaceScope.of(context);
    try {
      final c = await scope.controller.repository.client(widget.clientId),
          forms = await scope.planning!.forms();
      if (mounted) {
        setState(() {
          _client = c.client;
          _forms = forms;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = trainerError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => form(
    'Enviar formulario',
    [
      if (_loading) const LinearProgressIndicator(),
      if (_client != null)
        Text(_client!.name, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      if (_forms.isEmpty && !_loading)
        const Text('Crea primero una plantilla en Trainer web.'),
      for (final f in _forms)
        ListTile(
          selected: _selected?.versionId == f.versionId,
          leading: Icon(
            _selected?.versionId == f.versionId
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(f.title),
          subtitle: Text(
            '${f.questions.length} preguntas · Versión ${f.revision}',
          ),
          onTap: frozen
              ? null
              : () => setState(() {
                  _selected = f;
                  dirty = true;
                }),
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today),
        label: Text('Fecha límite: ${coachDate(_day)}'),
        onPressed: frozen
            ? null
            : () async {
                final d = await coachPickDay(context, _day);
                if (d != null && mounted) {
                  setState(() {
                    _day = d;
                    dirty = true;
                  });
                }
              },
      ),
      if (error != null && !frozen)
        TextButton(
          onPressed: _load,
          child: const Text('Actualizar plantillas'),
        ),
    ],
    label: 'Enviar al alumno',
    save: _selected == null || _client?.active != true
        ? null
        : () => write(
            (id) => CoachWorkspaceScope.of(context).planning!.sendForm(
              id,
              _client!.activeRelationId!,
              _selected!.versionId,
              _day,
            ),
          ),
  );
}

class CoachFormResponsePage extends StatelessWidget {
  const CoachFormResponsePage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Respuesta del formulario')),
    body: CoachLoad(
      load: () => CoachWorkspaceScope.of(context).planning!.formSubmission(id),
      builder: (context, a, refresh) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(a.form.title, style: Theme.of(context).textTheme.titleMedium),
          Text(a.statusLabel),
          for (final q in a.form.questions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(coachFormAnswer(a, q)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
