import 'trainer_catalog_search.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import 'trainer_groups_repository.dart';
import 'trainer_program_repository.dart';
import 'trainer_program_date_plan.dart';
import 'trainer_workout_repository.dart';

class TrainerGroupsPage extends StatefulWidget {
  const TrainerGroupsPage({
    super.key,
    required this.repository,
    required this.access,
    required this.workouts,
    required this.programs,
  });
  final TrainerGroupsRepository repository;
  final TrainerRepository access;
  final TrainerWorkoutRepository workouts;
  final TrainerProgramRepository programs;
  @override
  State<TrainerGroupsPage> createState() => _TrainerGroupsPageState();
}

class _TrainerGroupsPageState extends State<TrainerGroupsPage> {
  List<TrainerGroup> _groups = [];
  bool _busy = true, _more = false, _canWrite = false;
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
      final access = await widget.access.access();
      final rows = await widget.repository.groups(
        before: more && _groups.isNotEmpty ? _groups.last : null,
      );
      if (mounted) {
        setState(() {
          _groups = more ? [..._groups, ...rows] : rows;
          _more = rows.length == 50;
          _canWrite = access.effective;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([TrainerGroup? group]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GroupEditor(
        repository: widget.repository,
        access: widget.access,
        group: group,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _deliver([TrainerGroup? group]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrainerBatchAssignmentDialog(
        repository: widget.repository,
        access: widget.access,
        workouts: widget.workouts,
        programs: widget.programs,
        group: group,
        onOpenClient: (clientId, date) {
          // La planificación se apila encima del recibo: al volver se puede
          // continuar con otro destinatario de la misma entrega confirmada.
          context.push(trainerClientPlanningLocation(clientId, date));
        },
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Grupos y envíos'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar grupos',
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
              'Organiza tu cartera y prepara una entrega común con los destinatarios y las fechas a la vista. Cada alumno conserva su planificación personal.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy || !_canWrite ? null : () => _edit(),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Crear grupo'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || !_canWrite ? null : () => _deliver(),
                  icon: const Icon(Icons.send),
                  label: const Text('Nuevo envío'),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_busy && !_canWrite)
              const Text(
                'Puedes consultar tus grupos. Para modificarlos o enviar pautas necesitas acceso profesional vigente.',
              ),
            if (!_busy && _groups.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no tienes grupos. También puedes preparar un envío seleccionando alumnos directamente.',
                ),
              ),
            ProfessionalCatalogGrid(
              minCardWidth: 400,
              children: [
                for (final group in _groups)
                  Card(
                    key: ValueKey('trainer-group-${group.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${group.members.length} alumnos · ${group.members.where((m) => m.active).length} con vínculo activo',
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final member in group.members)
                                Chip(
                                  label: Text(
                                    '${member.name}${member.active ? '' : ' · inactivo'}',
                                  ),
                                ),
                            ],
                          ),
                          if (group.members.any((m) => !m.active))
                            const Text(
                              'Este grupo contiene alumnos inactivos. Edita sus destinatarios antes de enviar al grupo, o usa Nuevo envío para elegir una selección activa.',
                            ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: _busy || !_canWrite
                                    ? null
                                    : () => _edit(group),
                                child: const Text('Editar grupo'),
                              ),
                              FilledButton.tonal(
                                onPressed:
                                    _busy ||
                                        !_canWrite ||
                                        group.members.isEmpty ||
                                        group.members.any((m) => !m.active)
                                    ? null
                                    : () => _deliver(group),
                                child: const Text('Preparar envío al grupo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (_more)
              OutlinedButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Cargar más grupos'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
    required this.repository,
    required this.access,
    this.group,
  });
  final TrainerGroupsRepository repository;
  final TrainerRepository access;
  final TrainerGroup? group;
  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _id = widget.group?.id ?? trainerOperationId();
  late final _selected = {
    for (final m in widget.group?.members ?? <TrainerGroupMember>[]) m.clientId,
  };
  late final _names = {
    for (final m in widget.group?.members ?? <TrainerGroupMember>[])
      m.clientId: m.name,
  };
  TrainerClientState _state = TrainerClientState.active;
  List<TrainerClient> _clients = [];
  bool _busy = true, _more = false;
  String? _operation, _frozenName, _error;
  List<String>? _frozenClients;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final clients = await widget.access.clients(
        state: _state,
        before: more && _clients.isNotEmpty ? _clients.last : null,
      );
      if (mounted) {
        setState(() {
          _clients = more ? [..._clients, ...clients] : clients;
          _more = clients.length == 50;
          for (final c in clients) {
            _names[c.personId] = c.name;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _selected.length > 100) {
      setState(
        () => _error =
            'Introduce un nombre y selecciona como máximo 100 alumnos.',
      );
      return;
    }
    _operation ??= trainerOperationId();
    _frozenName ??= _name.text.trim();
    _frozenClients ??= List.unmodifiable(_selected.toList()..sort());
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveGroup(
        operationId: _operation!,
        id: _id,
        expectedRevision: widget.group?.revision ?? 0,
        name: _frozenName!,
        clientIds: _frozenClients!,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'No se ha podido confirmar el grupo. Reintenta con el mismo nombre y miembros. ${trainerError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: _GroupDialogFrame(
      title: widget.group == null ? 'Crear grupo de alumnos' : 'Editar grupo',
      body: [
        const Text(
          'Solo miembros de tu cartera. Guardar el grupo no envía entrenamientos ni reactiva vínculos.',
        ),
        TextField(
          key: const ValueKey('trainer-group-name'),
          controller: _name,
          enabled: !_busy && _operation == null,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Nombre del grupo'),
        ),
        Text('${_selected.length}/100 seleccionados'),
        if (_selected.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in _selected)
                InputChip(
                  label: Text(_names[id] ?? 'Alumno de tu cartera'),
                  onDeleted: _busy || _operation != null
                      ? null
                      : () => setState(() => _selected.remove(id)),
                ),
            ],
          ),
        DropdownButtonFormField<TrainerClientState>(
          initialValue: _state,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ver cartera'),
          items: [
            for (final state in TrainerClientState.values)
              DropdownMenuItem(
                value: state,
                child: Text(switch (state) {
                  TrainerClientState.active => 'Activos',
                  TrainerClientState.inactive => 'Inactivos',
                  TrainerClientState.archived => 'Archivados',
                }),
              ),
          ],
          onChanged: _busy || _operation != null
              ? null
              : (state) {
                  if (state != null) {
                    setState(() {
                      _state = state;
                      _clients = [];
                    });
                    _load();
                  }
                },
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final client in _clients)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(client.name),
            subtitle: Text(
              client.active
                  ? 'Vínculo activo'
                  : 'Consulta histórica; no se puede enviar',
            ),
            value: _selected.contains(client.personId),
            onChanged: _busy || _operation != null
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selected.add(client.personId);
                    } else {
                      _selected.remove(client.personId);
                    }
                  }),
          ),
        if (_more)
          TextButton(
            onPressed: _busy || _operation != null
                ? null
                : () => _load(more: true),
            child: const Text('Cargar más alumnos'),
          ),
      ],
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(
            _operation == null ? 'Guardar grupo' : 'Reintentar mismo grupo',
          ),
        ),
      ],
    ),
  );
}

class TrainerBatchAssignmentDialog extends StatefulWidget {
  const TrainerBatchAssignmentDialog({
    super.key,
    required this.repository,
    required this.access,
    required this.workouts,
    required this.programs,
    this.group,
    this.onOpenClient,
  });
  final TrainerGroupsRepository repository;
  final TrainerRepository access;
  final TrainerWorkoutRepository workouts;
  final TrainerProgramRepository programs;
  final TrainerGroup? group;
  final void Function(String clientId, DateTime firstDate)? onOpenClient;
  @override
  State<TrainerBatchAssignmentDialog> createState() =>
      _TrainerBatchAssignmentDialogState();
}

class _TrainerBatchAssignmentDialogState
    extends State<TrainerBatchAssignmentDialog> {
  final _catalogSearch = TrainerCatalogSearch();
  String _workoutQuery = '', _programQuery = '';
  final _workoutSearch = TextEditingController(),
      _programSearch = TextEditingController();
  TrainerWorkout? _workoutCursor;
  TrainerProgram? _programCursor;
  final _note = TextEditingController();
  late final Map<String, TrainerGroupMember> _selected = {
    for (final member in widget.group?.members ?? <TrainerGroupMember>[])
      member.clientId: member,
  };
  List<TrainerClient> _clients = [];
  List<TrainerWorkout> _workouts = [];
  List<TrainerProgram> _programs = [];
  TrainerWorkout? _workout;
  GuidedProgram? _program;
  DateTime? _date;
  final _dates = <(int, int), DateTime>{};
  int _phase = 0;
  bool _programMode = false,
      _busy = true,
      _moreClients = false,
      _moreWorkouts = false,
      _morePrograms = false;
  String? _error, _operation;
  TrainerBatchRequest? _request;
  TrainerBatchPreview? _preview;
  TrainerBatchReceipt? _receipt;
  bool get _frozen => _operation != null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catalogSearch.dispose();
    _workoutSearch.dispose();
    _programSearch.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load({String? more, bool search = false}) async {
    final request = _catalogSearch.begin();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (more == null || more == 'clients') {
        final rows = await widget.access.clients(
          before: more == 'clients' && _clients.isNotEmpty
              ? _clients.last
              : null,
        );
        if (!mounted) return;
        _clients = more == 'clients' ? [..._clients, ...rows] : rows;
        _moreClients = rows.length == 50;
      }
      if (more == null || more == 'workouts') {
        final rows = await widget.workouts.workouts(
          before: more == 'workouts' && !search ? _workoutCursor : null,
          query: _workoutQuery,
        );
        if (!mounted || !_catalogSearch.current(request)) return;
        _workoutCursor = rows.lastOrNull;
        _workouts = more == 'workouts' && !search
            ? [..._workouts, ...rows]
            : rows;
        final selected = _workout;
        if (selected != null &&
            !_workouts.any((row) => row.id == selected.id)) {
          _workouts = [selected, ..._workouts];
        }
        _moreWorkouts = rows.length == 50;
      }
      if (more == null || more == 'programs') {
        final rows = await widget.programs.programs(
          before: more == 'programs' && !search ? _programCursor : null,
          query: _programQuery,
        );
        if (!mounted || !_catalogSearch.current(request)) return;
        _programCursor = rows.lastOrNull;
        _programs = more == 'programs' && !search
            ? [..._programs, ...rows]
            : {
                for (final row in _programs)
                  if (row.program.id == _program?.id) row.program.id!: row,
                for (final row in rows) row.program.id!: row,
              }.values.toList();
        _morePrograms = rows.length == 50;
      }
    } catch (e) {
      if (mounted && _catalogSearch.current(request)) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted && _catalogSearch.current(request)) {
        setState(() => _busy = false);
      }
    }
  }

  List<(int, int)> get _slots => [
    if (_program != null)
      for (var pi = 0; pi < _program!.phases.length; pi++)
        if (_phase == -1 || pi == _phase)
          for (var si = 0; si < _program!.phases[pi].sessions.length; si++)
            (pi, si),
  ];
  String _dateLabel(DateTime? date) =>
      date == null ? 'Elegir fecha' : '${date.day}/${date.month}/${date.year}';
  Future<void> _pickDate([(int, int)? slot]) async {
    final existing = slot == null ? _date : _dates[slot];
    final date = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2200, 12, 31),
    );
    if (date != null && mounted) {
      setState(() {
        if (slot == null) {
          _date = date;
        } else {
          _dates[slot] = date;
        }
      });
    }
  }

  Future<void> _proposeDates() async {
    if (_busy || _frozen || _program == null || _slots.isEmpty) return;
    final existing = [
      for (final slot in _slots)
        if (_dates[slot] != null) _dates[slot]!,
    ]..sort();
    final first = existing.isEmpty
        ? DateUtils.dateOnly(DateTime.now())
        : existing.first;
    final start = await showDatePicker(
      context: context,
      helpText: 'Primera sesión · propuesta cada 2 días',
      initialDate: first.year >= 2020 && first.year <= 2100
          ? first
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
    );
    if (start == null || !mounted) return;
    final proposed = proposeTrainerProgramDates(_program!, _phase, start);
    if (proposed.any((entry) => entry.date.isAfter(DateTime(2100, 12, 31)))) {
      setState(
        () => _error = 'La propuesta termina después de 2100. Elige una fecha de inicio anterior.',
      );
      return;
    }
    if (existing.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: const Text('Reemplazar las fechas de las fases elegidas'),
          content: Text(
            'Se propondrán ${proposed.length} sesiones desde ${_dateLabel(start)}, separadas dos días. Después podrás ajustar cada fecha antes de revisar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Conservar fechas'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reemplazar fechas'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      for (final entry in proposed) {
        _dates[(entry.phase, entry.session)] = entry.date;
      }
      _error = null;
    });
  }

  DateTime? get _firstDeliveryDate {
    final request = _request;
    if (request == null) return null;
    if (request.date != null) return request.date;
    final dates = request.entries.map((entry) => entry.date).toList()..sort();
    return dates.firstOrNull;
  }

  String _entryName(TrainerProgramEntry entry) =>
      _program!.phases[entry.phase].sessions[entry.session].name;

  Future<void> _recipe(String id) async {
    try {
      final template = await widget.workouts.template(id);
      if (!mounted) return;
      if (template == null) throw StateError('Receta no disponible');
      await showDialog<void>(
        context: context,
        builder: (context) => EntrenaDialog(
          title: Text(template.name),
          content: WorkoutTemplateContent(template: template),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al envío'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    }
  }

  Future<void> _prepare() async {
    if (_busy || _frozen) return;
    final slots = _slots;
    if (_selected.isEmpty ||
        _selected.length > 100 ||
        _selected.values.any((m) => !m.active) ||
        (!_programMode && (_workout == null || _date == null)) ||
        (_programMode &&
            (_program == null ||
                slots.isEmpty ||
                slots.any((s) => !_dates.containsKey(s))))) {
      setState(
        () => _error = 'Elige alumnos activos, una receta y todas las fechas antes de revisar.',
      );
      return;
    }
    final count = _selected.length * (_programMode ? slots.length : 1);
    if (count > 256) {
      setState(
        () => _error =
            'El envío suma $count citas. Reduce alumnos o fases: el máximo es 256 citas por orden.',
      );
      return;
    }
    final request = TrainerBatchRequest(
      recipients: _selected.values.toList(),
      templateId: _programMode ? null : _workout!.id,
      date: _programMode ? null : _date,
      programId: _programMode ? _program!.id : null,
      entries: [
        if (_programMode)
          for (final slot in slots)
            TrainerProgramEntry(slot.$1, slot.$2, _dates[slot]!),
      ],
      note: _note.text.trim(),
      groupId: widget.group?.id,
      groupRevision: widget.group?.revision,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.repository.previewBatch(request);
      if (mounted) {
        setState(() {
          _request = request;
          _preview = preview;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _request == null || _preview == null) return;
    _operation ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.repository.deliverBatch(
        _operation!,
        _request!,
        _preview!.fingerprint,
      );
      if (mounted) setState(() => _receipt = receipt);
    } catch (e) {
      if (mounted) {
        if (e is PostgrestException && e.code == '40001') {
          setState(() {
            _operation = null;
            _request = null;
            _preview = null;
            _error = 'La planificación ha cambiado. Revisa de nuevo destinatarios, fechas y coincidencias antes de confirmar.';
          });
          return;
        }
        setState(
          () => _error =
              'No se ha podido confirmar la tanda. Reintenta con los mismos destinatarios, recetas y fechas. ${trainerError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview, receipt = _receipt;
    return PopScope(
      canPop: !_busy,
      child: _GroupDialogFrame(
        // Cada etapa empieza arriba; fechas, receta y UUID siguen en el padre.
        key: ValueKey(
          'trainer-batch-${receipt != null
              ? 'receipt'
              : preview != null
              ? 'preview'
              : 'selection'}',
        ),
        title: receipt != null
            ? 'Entrega confirmada'
            : widget.group == null
            ? 'Preparar envío conjunto'
            : 'Enviar a ${widget.group!.name}',
        body: [
          const Text(
            'Hasta 100 alumnos y 256 citas en total. La entrega es conjunta: si falla un destinatario, no se confirma ninguno.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (receipt != null) ...[
            Text('${receipt.assignmentCount} citas entregadas.'),
            const Text(
              'Cada alumno tiene sus propias pautas. Puedes adaptar su receta desde su planificación y revisar después sus resultados.',
            ),
            for (final result in receipt.recipients)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_selected[result.clientId]?.name ?? 'Alumno'}: ${result.assignmentIds.length} ${result.assignmentIds.length == 1 ? 'cita confirmada' : 'citas confirmadas'}.',
                      ),
                      if (widget.onOpenClient != null &&
                          _firstDeliveryDate != null &&
                          _selected.containsKey(result.clientId))
                        TextButton.icon(
                          key: ValueKey(
                            'trainer-batch-open-${result.clientId}',
                          ),
                          onPressed: () => widget.onOpenClient!(
                            result.clientId,
                            _firstDeliveryDate!,
                          ),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Ver y adaptar planificación'),
                        ),
                    ],
                  ),
                ),
              ),
          ] else if (preview != null) ...[
            Text(
              'Revisa ${preview.assignmentCount} citas para ${preview.recipients.length} alumnos.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Las coincidencias son por fecha: no sustituyen citas ni evalúan horarios o carga deportiva. Los planes personales se conservan.',
            ),
            Text(
              'Alumnos con coincidencias de fecha: ${preview.recipients.where((recipient) => recipient.coincidences.isNotEmpty).length}.',
            ),
            const Text('Planificación común que recibirá cada alumno:'),
            if (_request!.programId == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${_workout!.name} · v${_workout!.version}'),
                subtitle: Text(_dateLabel(_request!.date)),
                trailing: IconButton(
                  tooltip: 'Ver receta común',
                  onPressed: _busy
                      ? null
                      : () => _recipe(_request!.templateId!),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              )
            else
              for (final entry in _request!.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_dateLabel(entry.date)} · ${_entryName(entry)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Ver receta de ${_entryName(entry)}',
                    onPressed: _busy
                        ? null
                        : () => _recipe(
                            _program!
                                .phases[entry.phase]
                                .sessions[entry.session]
                                .templateId,
                          ),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ),
            for (final recipient in preview.recipients)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        recipient.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Fechas: ${recipient.dates.map(_dateLabel).join(', ')}',
                      ),
                      if (recipient.coincidences.isNotEmpty)
                        Text(
                          'Coincide con otras pautas: ${recipient.coincidences.map(_dateLabel).join(', ')}',
                        ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            if (widget.group == null) ...[
              const Text('Destinatarios de tu cartera activa'),
              for (final client in _clients)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(client.name),
                  value: _selected.containsKey(client.personId),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected[client.personId] = TrainerGroupMember(
                              clientId: client.personId,
                              name: client.name,
                              relationId: client.activeRelationId,
                            );
                          } else {
                            _selected.remove(client.personId);
                          }
                        }),
                ),
              if (_moreClients)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: 'clients'),
                  child: const Text('Cargar más alumnos'),
                ),
            ] else ...[
              Text('${_selected.length} destinatarios fijados de este grupo'),
              for (final member in _selected.values)
                Text(
                  '${member.name}${member.active ? '' : ' · vínculo inactivo'}',
                ),
            ],
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sesión suelta'),
                  selected: !_programMode,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _programMode = false),
                ),
                ChoiceChip(
                  label: const Text('Programa'),
                  selected: _programMode,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _programMode = true),
                ),
              ],
            ),
            if (!_programMode) ...[
              TextField(
                controller: _workoutSearch,
                decoration: const InputDecoration(
                  labelText: 'Buscar en todas mis sesiones',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _workoutQuery = value;
                    _busy = true;
                  });
                  _catalogSearch.schedule(
                    () => _load(more: 'workouts', search: true),
                  );
                },
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('trainer-batch-workout'),
                initialValue: _workout?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sesión privada'),
                items: [
                  for (final row in _workouts)
                    DropdownMenuItem(
                      value: row.id,
                      child: Text(
                        '${row.name} · v${row.version}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(
                        () => _workout = _workouts.firstWhere(
                          (row) => row.id == id,
                        ),
                      ),
              ),
              if (_moreWorkouts)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: 'workouts'),
                  child: const Text('Cargar más sesiones'),
                ),
              if (_workout != null)
                TextButton(
                  onPressed: _busy ? null : () => _recipe(_workout!.id),
                  child: const Text('Ver receta de la sesión'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('trainer-batch-date'),
                onPressed: _busy ? null : () => _pickDate(),
                icon: const Icon(Icons.calendar_month),
                label: Text(_dateLabel(_date)),
              ),
            ] else ...[
              TextField(
                controller: _programSearch,
                decoration: const InputDecoration(
                  labelText: 'Buscar en todos mis programas',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _programQuery = value;
                    _busy = true;
                  });
                  _catalogSearch.schedule(
                    () => _load(more: 'programs', search: true),
                  );
                },
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('trainer-batch-program'),
                initialValue: _program?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Programa privado',
                ),
                items: [
                  for (final row in _programs)
                    DropdownMenuItem(
                      value: row.program.id,
                      child: Text(
                        '${row.program.name} · v${row.program.version}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (id) => setState(() {
                        _program = _programs
                            .firstWhere((row) => row.program.id == id)
                            .program;
                        _phase = 0;
                        _dates.clear();
                      }),
              ),
              if (_morePrograms)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: 'programs'),
                  child: const Text('Cargar más programas'),
                ),
              if (_program != null) ...[
                const Text(
                  'Elige las fases y pon una fecha para cada sesión. Se asigna una pasada de las fases elegidas; no se generan repeticiones por su duración.',
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('trainer-batch-phase-${_program!.id}-$_phase'),
                  initialValue: _phase,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Fases que vas a pautar',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Todas las fases'),
                    ),
                    for (var pi = 0; pi < _program!.phases.length; pi++)
                      DropdownMenuItem(
                        value: pi,
                        child: Text(
                          _program!.phases[pi].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (phase) => setState(() => _phase = phase ?? 0),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('trainer-batch-propose-dates'),
                  onPressed: _busy || _frozen ? null : _proposeDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: const Text('Proponer fechas cada 2 días'),
                ),
                const Text(
                  'Es una propuesta editable de las fases elegidas. Revisa la disponibilidad de los alumnos antes de confirmar.',
                ),
                for (final slot in _slots)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_program!.phases[slot.$1].name} · ${_program!.phases[slot.$1].sessions[slot.$2].name}',
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _recipe(
                                    _program!
                                        .phases[slot.$1]
                                        .sessions[slot.$2]
                                        .templateId,
                                  ),
                            child: const Text('Ver receta fijada'),
                          ),
                          OutlinedButton(
                            key: ValueKey(
                              'trainer-batch-program-date-${slot.$1}-${slot.$2}',
                            ),
                            onPressed: _busy ? null : () => _pickDate(slot),
                            child: Text(_dateLabel(_dates[slot])),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
            TextField(
              controller: _note,
              enabled: !_busy,
              maxLength: _programMode ? 320 : 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Indicaciones para estos alumnos',
              ),
            ),
          ],
        ],
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.pop(context, receipt != null),
            child: Text(receipt == null ? 'Cerrar' : 'Terminar'),
          ),
          if (receipt == null && preview != null && !_frozen)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _preview = null;
                      _request = null;
                      _error = null;
                    }),
              child: const Text('Cambiar selección'),
            ),
          if (receipt == null)
            FilledButton(
              onPressed: _busy
                  ? null
                  : preview == null
                  ? _prepare
                  : _send,
              child: Text(
                preview == null
                    ? 'Revisar destinatarios y fechas'
                    : _frozen
                    ? 'Reintentar misma tanda'
                    : 'Confirmar ${preview.assignmentCount} citas',
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupDialogFrame extends StatelessWidget {
  const _GroupDialogFrame({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });
  final String title;
  final List<Widget> body, actions;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 860),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final child in body) ...[
                    child,
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ),
        ],
      ),
    ),
  );
}
