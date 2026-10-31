import 'trainer_catalog_search.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import 'trainer_groups_repository.dart';
import 'trainer_recurrence_repository.dart';
import 'trainer_workout_repository.dart';

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
bool _definitive(Object e) =>
    e is PostgrestException &&
    ['22023', '42501', '40001', '23503', '23514'].contains(e.code);

class TrainerRecurrencePage extends StatefulWidget {
  const TrainerRecurrencePage({
    super.key,
    required this.repository,
    required this.access,
    required this.workouts,
  });
  final TrainerRecurrenceRepository repository;
  final TrainerRepository access;
  final TrainerWorkoutRepository workouts;
  @override
  State<TrainerRecurrencePage> createState() => _TrainerRecurrencePageState();
}

class _TrainerRecurrencePageState extends State<TrainerRecurrencePage> {
  List<TrainerRecurrence> _rows = [];
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
      final rows = await widget.repository.series(
        before: more && _rows.isNotEmpty ? _rows.last : null,
      );
      if (mounted) {
        setState(() {
          _rows = more ? [..._rows, ...rows] : rows;
          _more = rows.length == 50;
          _canWrite = access.effective;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _create() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrainerRecurrenceEditorDialog(
        repository: widget.repository,
        access: widget.access,
        workouts: widget.workouts,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _withdraw(TrainerRecurrence series) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrainerRecurrenceWithdrawalDialog(
        repository: widget.repository,
        series: series,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Series planificadas'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Actualizar series',
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
              'Prepara una sesión para varios días durante un periodo cerrado. Todas las fechas se revisan y se crean juntas; no se generan citas indefinidamente.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy || !_canWrite ? null : _create,
                icon: const Icon(Icons.event_repeat),
                label: const Text('Planificar serie finita'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_busy && _rows.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aún no tienes series planificadas.'),
              ),
            ProfessionalCatalogGrid(
              minCardWidth: 380,
              children: [
                for (final row in _rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            row.templateName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Desde ${_date(row.weekStart)} · ${row.weeks} semanas · v${row.templateVersion}',
                          ),
                          Text(
                            row.weekdays
                                .map((d) => _weekdays[d - 1])
                                .join(', '),
                          ),
                          Text(
                            '${row.assignmentCount} citas creadas · ${row.pendingCount} pendientes',
                          ),
                          TextButton(
                            onPressed:
                                _busy || !_canWrite || row.pendingCount == 0
                                ? null
                                : () => _withdraw(row),
                            child: const Text('Retirar próximas pautas'),
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
                child: const Text('Cargar más series'),
              ),
          ],
        ),
      ),
    ),
  );
}

class TrainerRecurrenceEditorDialog extends StatefulWidget {
  const TrainerRecurrenceEditorDialog({
    super.key,
    required this.repository,
    required this.access,
    required this.workouts,
  });
  final TrainerRecurrenceRepository repository;
  final TrainerRepository access;
  final TrainerWorkoutRepository workouts;
  @override
  State<TrainerRecurrenceEditorDialog> createState() =>
      _TrainerRecurrenceEditorDialogState();
}

class _TrainerRecurrenceEditorDialogState
    extends State<TrainerRecurrenceEditorDialog> {
  final _note = TextEditingController();
  final _selected = <String, TrainerGroupMember>{};
  final _days = <int>{};
  List<TrainerClient> _clients = [];
  List<TrainerWorkout> _workouts = [];
  TrainerWorkout? _workout;
  DateTime? _monday;
  int _weeks = 1;
  bool _busy = true,
      _moreClients = false,
      _moreWorkouts = false,
      _reprepare = false;
  String? _error, _operation;
  TrainerRecurrenceRequest? _request;
  TrainerRecurrencePreview? _preview;
  TrainerRecurrenceReceipt? _receipt;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catalogSearch.dispose();
    _workoutSearch.dispose();
    _note.dispose();
    super.dispose();
  }

  final _catalogSearch = TrainerCatalogSearch();
  String _workoutQuery = '';
  final _workoutSearch = TextEditingController();
  TrainerWorkout? _searchCursor;

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
        _clients = more == 'clients' ? [..._clients, ...rows] : rows;
        _moreClients = rows.length == 50;
      }
      if (more == null || more == 'workouts') {
        final rows = await widget.workouts.workouts(
          before: more == 'workouts' && !search ? _searchCursor : null,
          query: _workoutQuery,
        );
        if (!mounted || !_catalogSearch.current(request)) return;
        _searchCursor = rows.lastOrNull;
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

  Future<void> _chooseMonday() async {
    final now = DateTime.now();
    final initial =
        _monday ?? DateTime(now.year, now.month, now.day - now.weekday + 1);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200, 12, 31),
      selectableDayPredicate: (day) => day.weekday == DateTime.monday,
    );
    if (date != null && mounted) {
      setState(() => _monday = date);
    }
  }

  Future<void> _recipe() async {
    if (_workout == null) return;
    try {
      final template = await widget.workouts.template(_workout!.id);
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
              child: const Text('Volver a la serie'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = trainerError(e));
      }
    }
  }

  Future<void> _prepare() async {
    if (_busy) return;
    if (_selected.isEmpty ||
        _selected.length > 100 ||
        _selected.values.any((m) => !m.active) ||
        _workout == null ||
        _monday == null ||
        _days.isEmpty) {
      setState(
        () => _error =
            'Elige alumnos activos, sesión, lunes inicial y días de la semana.',
      );
      return;
    }
    final count = _selected.length * _weeks * _days.length;
    if (count > 256) {
      setState(
        () => _error =
            'La serie suma $count citas. Reduce alumnos, semanas o días: el máximo es 256.',
      );
      return;
    }
    final request = TrainerRecurrenceRequest(
      recipients: _selected.values.toList(),
      templateId: _workout!.id,
      weekStart: _monday!,
      weeks: _weeks,
      weekdays: _days.toList(),
      note: _note.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.repository.preview(request);
      if (mounted) {
        setState(() {
          _request = request;
          _preview = preview;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _create() async {
    if (_busy || _preview == null || _request == null || _reprepare) return;
    _operation ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.repository.create(
        _operation!,
        _request!,
        _preview!.fingerprint,
      );
      if (mounted) {
        setState(() => _receipt = receipt);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reprepare = _definitive(e);
          _error = _reprepare
              ? 'No se ha creado la serie. ${trainerError(e)} Vuelve a preparar sus fechas.'
              : 'No se pudo confirmar la serie. Reintenta la misma orden sin cambiar destinatarios o fechas.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reset() async {
    setState(() {
      _preview = null;
      _request = null;
      _operation = null;
      _reprepare = false;
      _workout = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview, receipt = _receipt;
    return PopScope(
      canPop: !_busy,
      child: _RecurrenceDialogFrame(
        title: receipt == null ? 'Planificar serie finita' : 'Serie confirmada',
        body: [
          const Text(
            'Entre 1 y 12 semanas. Elige días concretos y revisa todas las fechas antes de crear. Máximo 100 alumnos y 256 citas por serie.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (receipt != null) ...[
            Text('${receipt.batch.assignmentCount} citas creadas.'),
            for (final result in receipt.batch.recipients)
              Text(
                '${_selected[result.clientId]?.name ?? 'Alumno'}: ${result.assignmentIds.length} citas confirmadas.',
              ),
          ] else if (preview != null) ...[
            Text(
              '${preview.batch.assignmentCount} citas para ${preview.batch.recipients.length} alumnos.',
            ),
            const Text(
              'Las coincidencias son por fecha. No se sustituyen planes ni se modifica la receta de biblioteca. La serie termina tras las semanas elegidas.',
            ),
            for (final recipient in preview.batch.recipients)
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
                      Text(recipient.dates.map(_date).join(', ')),
                      if (recipient.coincidences.isNotEmpty)
                        Text(
                          'Coincidencias: ${recipient.coincidences.map(_date).join(', ')}',
                        ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            const Text('Alumnos de tu cartera activa'),
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final member in _selected.values)
                    InputChip(
                      label: Text(member.name),
                      onDeleted: _busy
                          ? null
                          : () => setState(
                              () => _selected.remove(member.clientId),
                            ),
                    ),
                ],
              ),
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
              key: const ValueKey('recurrence-template'),
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
                      () => _workout = _workouts.firstWhere((w) => w.id == id),
                    ),
            ),
            if (_moreWorkouts)
              TextButton(
                onPressed: _busy ? null : () => _load(more: 'workouts'),
                child: const Text('Cargar más sesiones'),
              ),
            if (_workout != null)
              TextButton(
                onPressed: _busy ? null : _recipe,
                child: const Text('Ver receta fijada'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('recurrence-monday'),
              onPressed: _busy ? null : _chooseMonday,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _monday == null
                    ? 'Elegir lunes inicial'
                    : 'Lunes ${_date(_monday!)}',
              ),
            ),
            DropdownButtonFormField<int>(
              key: const ValueKey('recurrence-weeks'),
              initialValue: _weeks,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Número de semanas'),
              items: [
                for (var n = 1; n <= 12; n++)
                  DropdownMenuItem(
                    value: n,
                    child: Text('$n ${n == 1 ? 'semana' : 'semanas'}'),
                  ),
              ],
              onChanged: _busy ? null : (n) => setState(() => _weeks = n ?? 1),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdays[d - 1]),
                    selected: _days.contains(d),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _days.add(d);
                            } else {
                              _days.remove(d);
                            }
                          }),
                  ),
              ],
            ),
            TextField(
              controller: _note,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Indicaciones de la serie',
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
          if (receipt == null &&
              preview != null &&
              (_operation == null || _reprepare))
            TextButton(
              onPressed: _busy ? null : _reset,
              child: const Text('Volver a preparar'),
            ),
          if (receipt == null && !_reprepare)
            FilledButton(
              onPressed: _busy
                  ? null
                  : preview == null
                  ? _prepare
                  : _create,
              child: Text(
                preview == null
                    ? 'Revisar todas las fechas'
                    : _operation == null
                    ? 'Crear ${preview.batch.assignmentCount} citas'
                    : 'Reintentar misma serie',
              ),
            ),
        ],
      ),
    );
  }
}

class TrainerRecurrenceWithdrawalDialog extends StatefulWidget {
  const TrainerRecurrenceWithdrawalDialog({
    super.key,
    required this.repository,
    required this.series,
  });
  final TrainerRecurrenceRepository repository;
  final TrainerRecurrence series;
  @override
  State<TrainerRecurrenceWithdrawalDialog> createState() =>
      _TrainerRecurrenceWithdrawalDialogState();
}

class _TrainerRecurrenceWithdrawalDialogState
    extends State<TrainerRecurrenceWithdrawalDialog> {
  DateTime? _from;
  TrainerRecurrenceWithdrawal? _preview;
  String? _error, _operation;
  bool _busy = false, _reprepare = false;
  int? _cancelled;
  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2200, 12, 31),
    );
    if (!mounted || date == null) return;
    setState(() => _from = date);
    await _load();
  }

  Future<void> _load() async {
    if (_from == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _operation = null;
      _reprepare = false;
      _preview = null;
    });
    try {
      final preview = await widget.repository.previewWithdrawal(
        widget.series.id,
        _from!,
      );
      if (mounted) {
        setState(() => _preview = preview);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = trainerError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _withdraw() async {
    if (_busy ||
        _from == null ||
        _preview == null ||
        _preview!.items.isEmpty ||
        _reprepare) {
      return;
    }
    _operation ??= trainerOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cancelled = await widget.repository.withdraw(
        _operation!,
        widget.series.id,
        _from!,
        _preview!.fingerprint,
      );
      if (mounted) {
        setState(() => _cancelled = cancelled);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reprepare = _definitive(e);
          _error = _reprepare
              ? 'No se han retirado pautas. ${trainerError(e)} Vuelve a revisar.'
              : 'No se ha podido confirmar la retirada. Reintenta la misma orden; no cambies la fecha.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: _RecurrenceDialogFrame(
      title: 'Retirar próximas pautas',
      body: [
        Text(widget.series.templateName),
        const Text(
          'Solo se retirarán pautas de esta serie que sigan pendientes y sin ejecución desde la fecha elegida, incluida esa fecha. No se interrumpe lo iniciado, no se borra historial y no se da de baja a los alumnos.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_cancelled != null)
          Text('Retirada confirmada: $_cancelled pautas.')
        else ...[
          OutlinedButton(
            key: const ValueKey('recurrence-withdraw-date'),
            onPressed: _busy || (_operation != null && !_reprepare)
                ? null
                : _chooseDate,
            child: Text(
              _from == null
                  ? 'Elegir desde qué fecha'
                  : 'Desde ${_date(_from!)}',
            ),
          ),
          if (_preview != null) ...[
            Text(
              '${_preview!.items.length} pautas pendientes para retirar · ${_preview!.excludedCount} excluidas.',
            ),
            for (final item in _preview!.items)
              Text('${item.clientName} · ${_date(item.date)}'),
            if (_preview!.items.isEmpty)
              const Text(
                'No hay pautas pendientes para retirar desde esta fecha.',
              ),
          ],
        ],
      ],
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, _cancelled != null),
          child: Text(_cancelled == null ? 'Cerrar' : 'Terminar'),
        ),
        if (_cancelled == null && _reprepare)
          OutlinedButton(
            onPressed: _busy ? null : _load,
            child: const Text('Volver a revisar'),
          ),
        if (_cancelled == null &&
            _preview != null &&
            _preview!.items.isNotEmpty &&
            !_reprepare)
          OutlinedButton(
            onPressed: _busy ? null : _withdraw,
            style: EntrenaButtonStyles.destructive(context),
            child: Text(
              _operation == null
                  ? 'Confirmar retirada de ${_preview!.items.length} pautas'
                  : 'Reintentar misma retirada',
            ),
          ),
      ],
    ),
  );
}

class _RecurrenceDialogFrame extends StatelessWidget {
  const _RecurrenceDialogFrame({
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
                  for (final item in body) ...[
                    item,
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
