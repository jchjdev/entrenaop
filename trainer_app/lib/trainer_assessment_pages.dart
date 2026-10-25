import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_editor_ui/assessment_capture_fields.dart';

import 'trainer_assessment_repository.dart';
import 'trainer_workout_repository.dart';

String _error(Object e) => e is FormatException ? e.message : trainerError(e);
String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
String _unit(ProfessionalMarkUnit unit) => switch (unit) {
  ProfessionalMarkUnit.repetitions => 'rep',
  ProfessionalMarkUnit.seconds => 's',
  ProfessionalMarkUnit.meters => 'm',
};

class TrainerAssessmentsPage extends StatefulWidget {
  const TrainerAssessmentsPage({
    super.key,
    required this.repository,
    required this.access,
  });
  final TrainerAssessmentRepository repository;
  final TrainerRepository access;
  @override
  State<TrainerAssessmentsPage> createState() => _TrainerAssessmentsPageState();
}

class _TrainerAssessmentsPageState extends State<TrainerAssessmentsPage> {
  List<ProfessionalAssessmentVersion> _items = [];
  bool _busy = true, _enabled = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final enabled = (await widget.access.access()).effective;
      final items = await widget.repository.list();
      if (mounted) {
        setState(() {
          _items = items;
          _enabled = enabled;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([ProfessionalAssessmentVersion? item]) async {
    await context.push(
      item == null ? '/assessments/new' : '/assessments/${item.id}/revise',
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pruebas y simulacros'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EntrenaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Evalúa y compara marcas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Una batería agrupa las pruebas de una evaluación o simulacro. Crea las instrucciones, asígnala a un alumno y consulta sus intentos y resultados.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Por ejemplo: dominadas en repeticiones, carrera de 1.000 m en tiempo y salto en metros.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Se registran marcas de entrenamiento; no se calculan puntos ni aptitud oficial.',
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Cómo usar las pruebas'),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '1. Crea una batería con sus pruebas e instrucciones.\n2. Abre Alumnos → ficha del alumno → Pruebas y simulacros para asignarla.\n3. El alumno registra sus intentos en la app.\n4. Consulta sus marcas y compara entregas con las mismas condiciones.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy || !_enabled ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Crear batería'),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        ProfessionalCatalogGrid(
          minCardWidth: 340,
          children: [
            for (final item in _items)
              Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.tests.length} pruebas · versión ${item.version}',
                  ),
                  trailing: TextButton(
                    onPressed: !_enabled ? null : () => _edit(item),
                    child: const Text('Revisar'),
                  ),
                ),
              ),
          ],
        ),
        if (!_busy && _items.isEmpty && _message == null)
          const Text('Todavía no has creado baterías privadas.'),
      ],
    ),
  );
}

class _ProtocolFields {
  _ProtocolFields([ProfessionalAssessmentTest? test])
    : id = test?.id ?? trainerOperationId(),
      name = TextEditingController(text: test?.name),
      instructions = TextEditingController(text: test?.instructions),
      resolution = TextEditingController(
        text: test?.resolution.toString() ?? '1',
      ),
      attempts = TextEditingController(
        text: test?.maximumAttempts.toString() ?? '1',
      ),
      unit = test?.unit ?? ProfessionalMarkUnit.repetitions,
      direction = test?.direction ?? ProfessionalBetterDirection.higher,
      retry = test?.retryPolicy ?? ProfessionalRetryPolicy.none,
      official = test?.source == ProfessionalProtocolSource.official
          ? test
          : null;
  final String id;
  final TextEditingController name, instructions, resolution, attempts;
  ProfessionalMarkUnit unit;
  ProfessionalBetterDirection direction;
  ProfessionalRetryPolicy retry;
  final ProfessionalAssessmentTest? official;
  ProfessionalAssessmentTest value() =>
      official ??
      ProfessionalAssessmentTest(
        id: id,
        name: name.text.trim(),
        instructions: instructions.text.trim(),
        unit: unit,
        direction: direction,
        resolution: double.parse(resolution.text.trim().replaceAll(',', '.')),
        maximumAttempts: int.parse(attempts.text.trim()),
        retryPolicy: retry,
      );
  void dispose() {
    for (final c in [name, instructions, resolution, attempts]) {
      c.dispose();
    }
  }
}

class TrainerAssessmentEditorPage extends StatefulWidget {
  const TrainerAssessmentEditorPage({
    super.key,
    required this.repository,
    this.assessmentId,
  });
  final TrainerAssessmentRepository repository;
  final String? assessmentId;
  @override
  State<TrainerAssessmentEditorPage> createState() =>
      _TrainerAssessmentEditorPageState();
}

class _TrainerAssessmentEditorPageState
    extends State<TrainerAssessmentEditorPage> {
  final _title = TextEditingController(),
      _description = TextEditingController();
  final _tests = <_ProtocolFields>[];
  final _operation = trainerOperationId();
  ProfessionalAssessmentVersion? _initial, _pending;
  bool _busy = false, _loading = false, _dirty = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    if (widget.assessmentId == null) {
      _tests.add(_ProtocolFields());
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final test in _tests) {
      test.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final form = await widget.repository.get(widget.assessmentId!);
      if (!mounted) return;
      setState(() {
        _initial = form;
        _title.text = form.title;
        _description.text = form.description ?? '';
        _tests.addAll(form.tests.map(_ProtocolFields.new));
      });
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _catalog() async {
    setState(() => _busy = true);
    try {
      final tests = await widget.repository.catalog();
      if (!mounted) return;
      if (tests.isEmpty) {
        setState(
          () => _message = 'No hay protocolos oficiales publicados que cumplan el contrato íntegro de captura disponible. Puedes definir uno privado explícito.',
        );
        return;
      }
      final selected = await showDialog<ProfessionalAssessmentTest>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Catálogo oficial compatible'),
          children: [
            for (final test in tests)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, test),
                child: Text('${test.name} · ${_unit(test.unit)}'),
              ),
          ],
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _tests.add(_ProtocolFields(selected));
          _dirty = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      _pending ??= ProfessionalAssessmentValidator.normalize(
        ProfessionalAssessmentVersion(
          id: _operation,
          familyId: _initial?.familyId ?? _operation,
          version: (_initial?.version ?? 0) + 1,
          title: _title.text,
          description: _description.text,
          tests: _tests.map((t) => t.value()),
        ),
      );
      await widget.repository.save(
        _operation,
        _pending!,
        previousId: widget.assessmentId,
        expectedRevision: _initial?.version ?? 0,
      );
      if (mounted) {
        _dirty = false;
        _pending = null;
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/assessments');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty || _pending != null,
    isBusy: () => _busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assessmentId == null
              ? 'Crear batería privada'
              : 'Revisar batería',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(
            context,
            maxWidth: 900,
          ),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_message != null) Text(_message!),
              if (!_loading && widget.assessmentId != null && _initial == null)
                TextButton(
                  onPressed: _load,
                  child: const Text('Reintentar carga'),
                ),
              const Text(
                'Los cambios crean otra versión. Las pruebas ya enviadas conservan sus protocolos. Un protocolo privado nunca se presenta como baremo oficial.',
              ),
              ExcludeFocus(
                excluding: _busy || _loading || _pending != null,
                child: AbsorbPointer(
                  absorbing: _busy || _loading || _pending != null,
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Título de la batería',
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      TextField(
                        controller: _description,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción opcional',
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      for (var i = 0; i < _tests.length; i++) _protocol(i),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _tests.length >= 40
                                ? null
                                : () => setState(() {
                                    _tests.add(_ProtocolFields());
                                    _dirty = true;
                                  }),
                            child: const Text('Añadir protocolo privado'),
                          ),
                          TextButton(
                            onPressed: _tests.length >= 40 ? null : _catalog,
                            child: const Text('Añadir del catálogo oficial'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_pending != null)
                const Text(
                  'Reintenta para confirmar exactamente la batería y revisión enviadas.',
                ),
              FilledButton(
                onPressed:
                    _busy ||
                        _loading ||
                        (widget.assessmentId != null && _initial == null)
                    ? null
                    : _save,
                child: Text(
                  _busy
                      ? 'Guardando…'
                      : _pending == null
                      ? 'Guardar versión'
                      : 'Reintentar el mismo guardado',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _protocol(int index) {
    final t = _tests[index];
    return Card(
      key: ValueKey(t.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Prueba ${index + 1}')),
                IconButton(
                  tooltip: 'Subir prueba',
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          _tests.removeAt(index);
                          _tests.insert(index - 1, t);
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Eliminar prueba',
                  onPressed: () => setState(() {
                    _tests.removeAt(index);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => t.dispose(),
                    );
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (t.official != null) ...[
              Text('${t.official!.name} · fuente oficial publicada'),
              Text(t.official!.instructions),
              Text(
                'Las condiciones se fijan desde el servidor; no se editan ni se puntúan aquí.',
              ),
            ] else ...[
              TextField(
                controller: t.name,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la prueba',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              TextField(
                controller: t.instructions,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Protocolo completo y condiciones',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              DropdownButtonFormField<ProfessionalMarkUnit>(
                initialValue: t.unit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Unidad'),
                items: ProfessionalMarkUnit.values
                    .map(
                      (u) => DropdownMenuItem(value: u, child: Text(_unit(u))),
                    )
                    .toList(),
                onChanged: (u) {
                  if (u != null) {
                    setState(() {
                      t.unit = u;
                      _dirty = true;
                    });
                  }
                },
              ),
              DropdownButtonFormField<ProfessionalBetterDirection>(
                initialValue: t.direction,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dirección favorable',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ProfessionalBetterDirection.higher,
                    child: Text('Mayor marca es mejor'),
                  ),
                  DropdownMenuItem(
                    value: ProfessionalBetterDirection.lower,
                    child: Text('Menor marca es mejor'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      t.direction = v;
                      _dirty = true;
                    });
                  }
                },
              ),
              TextField(
                controller: t.resolution,
                decoration: const InputDecoration(
                  labelText: 'Resolución de marca',
                  helperText:
                      'Por ejemplo 1 rep, 0,01 s o 0,1 m. No se redondea.',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              TextField(
                controller: t.attempts,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Máximo de intentos (1 a 10)',
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              DropdownButtonFormField<ProfessionalRetryPolicy>(
                initialValue: t.retry,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Política de repetición',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ProfessionalRetryPolicy.none,
                    child: Text('Un solo intento'),
                  ),
                  DropdownMenuItem(
                    value: ProfessionalRetryPolicy.always,
                    child: Text('Repetición libre hasta el máximo'),
                  ),
                  DropdownMenuItem(
                    value: ProfessionalRetryPolicy.invalidOnly,
                    child: Text('Solo repetir tras nulo'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      t.retry = v;
                      _dirty = true;
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TrainerClientAssessmentsPage extends StatefulWidget {
  const TrainerClientAssessmentsPage({
    super.key,
    required this.repository,
    required this.client,
  });
  final TrainerAssessmentRepository repository;
  final TrainerClient client;
  @override
  State<TrainerClientAssessmentsPage> createState() =>
      _TrainerClientAssessmentsPageState();
}

class _TrainerClientAssessmentsPageState
    extends State<TrainerClientAssessmentsPage> {
  List<ProfessionalAssessmentDelivery> _items = [];
  bool _busy = true, _more = false;
  String? _message, _previous, _current;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final rows = await widget.repository.deliveries(
        widget.client.personId,
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
          if (!_items.any((d) => d.id == _previous)) _previous = null;
          if (!_items.any((d) => d.id == _current)) _current = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    setState(() => _busy = true);
    try {
      final batteries = await widget.repository.list();
      if (!mounted) return;
      if (batteries.isEmpty) {
        setState(() => _message = 'Crea primero una batería privada.');
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AssignAssessmentDialog(
          repository: widget.repository,
          relationId: widget.client.activeRelationId!,
          items: batteries,
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _items.where((d) => d.status == 'completed').toList();
    final previous = completed.where((d) => d.id == _previous).singleOrNull,
        current = completed.where((d) => d.id == _current).singleOrNull;
    final comparisons = previous == null || current == null
        ? const <ProfessionalMarkComparison>[]
        : compareProfessionalAssessments(previous, current);
    return Scaffold(
      appBar: AppBar(
        title: Text('Pruebas · ${widget.client.name}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.client.active)
            FilledButton(
              onPressed: _busy ? null : _assign,
              child: const Text('Asignar batería'),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(item.battery.title),
                subtitle: Text(
                  '${item.statusLabel} · pautada ${_date(item.scheduledDate)} · versión ${item.battery.version}',
                ),
                onTap: () async {
                  await context.push(
                    '/clients/${widget.client.personId}/assessments/${item.id}',
                  );
                  if (mounted) await _load();
                },
              ),
            ),
          if (_more)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Cargar anteriores'),
            ),
          if (completed.length >= 2) ...[
            const Divider(),
            const Text('Comparar marcas de entregas cargadas'),
            const Text(
              'Selecciona dos registros de este servicio, con fecha anterior estricta. Solo se comparan protocolos íntegros coincidentes; no puntos ni aptitud.',
            ),
            DropdownButtonFormField<String>(
              initialValue: _previous,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Registro anterior'),
              items: completed
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.battery.title} · ${_date(d.completedAt!)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _previous = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: _current,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Registro reciente'),
              items: completed
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.battery.title} · ${_date(d.completedAt!)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _current = v),
            ),
            if (previous != null && current != null && comparisons.isEmpty)
              const Text(
                'No hay marcas válidas comparables entre esos registros, o las fechas no tienen el orden requerido.',
              ),
            for (final comparison in comparisons)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${comparison.test.name}: ${comparison.previous} → ${comparison.current} ${_unit(comparison.test.unit)} · cambio favorable ${comparison.favorableDifference} ${_unit(comparison.test.unit)}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AssignAssessmentDialog extends StatefulWidget {
  const _AssignAssessmentDialog({
    required this.repository,
    required this.relationId,
    required this.items,
  });
  final TrainerAssessmentRepository repository;
  final String relationId;
  final List<ProfessionalAssessmentVersion> items;
  @override
  State<_AssignAssessmentDialog> createState() =>
      _AssignAssessmentDialogState();
}

class _AssignAssessmentDialogState extends State<_AssignAssessmentDialog> {
  final _operation = trainerOperationId();
  late String _id = widget.items.first.id;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _busy = false, _sent = false;
  String? _message;
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _sent = true;
      _message = null;
    });
    try {
      await widget.repository.assign(_operation, widget.relationId, _id, _date);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Asignar prueba o simulacro'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _id,
                isExpanded: true,
                items: widget.items
                    .map(
                      (b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.title)),
                    )
                    .toList(),
                onChanged: _sent ? null : (v) => setState(() => _id = v!),
              ),
              TextButton(
                onPressed: _sent
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2200, 12, 31),
                        );
                        if (selected != null && mounted) {
                          setState(() => _date = selected);
                        }
                      },
                child: Text('Fecha ${_date.day}/${_date.month}/${_date.year}'),
              ),
              if (_message != null) Text(_message!),
              if (_sent) const Text('Reintenta para confirmar el mismo envío.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_sent ? 'Reintentar envío' : 'Asignar'),
        ),
      ],
    ),
  );
}

class TrainerAssessmentDeliveryPage extends StatefulWidget {
  const TrainerAssessmentDeliveryPage({
    super.key,
    required this.repository,
    required this.deliveryId,
  });
  final TrainerAssessmentRepository repository;
  final String deliveryId;
  @override
  State<TrainerAssessmentDeliveryPage> createState() =>
      _TrainerAssessmentDeliveryPageState();
}

class _TrainerAssessmentDeliveryPageState
    extends State<TrainerAssessmentDeliveryPage> {
  ProfessionalAssessmentDelivery? _item;
  String? _message;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final item = await widget.repository.delivery(widget.deliveryId);
      if (mounted) setState(() => _item = item);
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado de pruebas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
          if (item != null) ...[
            Text(
              '${item.clientName} · ${item.battery.title} · ${item.statusLabel}',
            ),
            if (item.completedAt != null)
              Text('Registro cerrado el ${_date(item.completedAt!.toLocal())}'),
            const Text(
              'Consulta de marcas del servicio. El preparador no modifica resultados del alumno ni obtiene puntuación oficial.',
            ),
            if (item.status == 'completed' || item.status == 'in_progress')
              AssessmentCaptureFields(
                key: ValueKey('${item.id}-${item.revision}'),
                form: item.battery,
                initialAnswers: item.answers,
                readOnly: true,
                onChanged: (_) {},
              ),
            if (item.status == 'completed')
              for (final test in item.battery.tests)
                Text(
                  '${test.name}: mejor marca válida ${ProfessionalAssessmentValidator.best(test, item.answers[test.id] ?? const []) ?? 'Sin marca válida'} ${_unit(test.unit)}',
                ),
          ],
        ],
      ),
    );
  }
}
