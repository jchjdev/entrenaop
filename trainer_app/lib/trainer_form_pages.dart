import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

import 'trainer_form_repository.dart';
import 'trainer_workout_repository.dart';

String trainerFormError(Object error) =>
    error is FormatException ? error.message : trainerError(error);
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

class TrainerFormsPage extends StatefulWidget {
  const TrainerFormsPage({
    super.key,
    required this.repository,
    required this.access,
  });
  final TrainerFormRepository repository;
  final TrainerRepository access;
  @override
  State<TrainerFormsPage> createState() => _TrainerFormsPageState();
}

class _TrainerFormsPageState extends State<TrainerFormsPage> {
  List<TrainerFollowupFormVersion> _forms = [];
  bool _busy = true, _enabled = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = (await widget.access.access()).effective;
      final forms = await widget.repository.list();
      if (mounted) {
        setState(() {
          _forms = forms;
          _enabled = enabled;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([TrainerFollowupFormVersion? form]) async {
    await context.push(
      form == null ? '/forms/new' : '/forms/${form.versionId}/revise',
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis formularios'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
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
            const Text(
              'Prepara cuestionarios privados de incorporación o revisión. Cada envío conserva su versión y admite una respuesta completa.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: !_enabled || _busy ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Crear formulario'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_busy && _forms.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no has creado formularios.'),
              ),
            ProfessionalCatalogGrid(
              children: [
                for (final form in _forms)
                  ProfessionalResourceCard(
                    leading: const ProfessionalResourceIcon(
                      Icons.assignment_outlined,
                    ),
                    title: Text(form.title),
                    subtitle: Text(
                      'Versión ${form.revision} · ${form.questions.length} preguntas',
                    ),
                    trailing: TextButton(
                      onPressed: !_enabled ? null : () => _edit(form),
                      child: const Text('Revisar'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestionFields {
  _QuestionFields({String? id, TrainerFollowupQuestion? initial})
    : id = initial?.id ?? id ?? trainerOperationId(),
      prompt = TextEditingController(text: initial?.prompt),
      help = TextEditingController(text: initial?.help),
      options = TextEditingController(
        text: initial?.options.map((o) => o.label).join('\n'),
      ),
      minimum = TextEditingController(text: _boundText(initial?.minimum)),
      maximum = TextEditingController(text: _boundText(initial?.maximum)),
      maximumSelections = TextEditingController(
        text: initial?.maximumSelections?.toString(),
      ),
      type = initial?.type ?? TrainerFollowupQuestionType.shortText,
      required = initial?.required ?? false,
      optionIds = initial?.options.map((o) => o.id).toList() ?? [];
  final String id;
  final TextEditingController prompt,
      help,
      options,
      minimum,
      maximum,
      maximumSelections;
  TrainerFollowupQuestionType type;
  bool required;
  final List<String> optionIds;
  static String? _boundText(double? value) {
    final text = value?.toString();
    // Conserva el valor de un límite antiguo sin presentar un separador ambiguo.
    return text != null && RegExp(r'^[+-]?[1-9]\d{0,2}\.\d{3}$').hasMatch(text)
        ? '${text}0'
        : text;
  }

  void dispose() {
    for (final c in [
      prompt,
      help,
      options,
      minimum,
      maximum,
      maximumSelections,
    ]) {
      c.dispose();
    }
  }

  TrainerFollowupQuestion value(int position) {
    final choice =
        type == TrainerFollowupQuestionType.singleChoice ||
        type == TrainerFollowupQuestionType.multipleChoice;
    final labels = choice
        ? options.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList()
        : <String>[];
    while (optionIds.length < labels.length) {
      optionIds.add(trainerOperationId());
    }
    double? number(String text) {
      if (text.trim().isEmpty) return null;
      return TrainerFollowupValidator.normalizeNumber(text);
    }

    final numeric =
        type == TrainerFollowupQuestionType.number ||
        type == TrainerFollowupQuestionType.scale;
    return TrainerFollowupQuestion(
      id: id,
      position: position,
      prompt: prompt.text,
      help: help.text,
      type: type,
      required: required,
      options: [
        for (var i = 0; i < labels.length; i++)
          TrainerFollowupOption(id: optionIds[i], label: labels[i]),
      ],
      minimum: numeric ? number(minimum.text) : null,
      maximum: numeric ? number(maximum.text) : null,
      maximumSelections:
          type == TrainerFollowupQuestionType.multipleChoice &&
              maximumSelections.text.trim().isNotEmpty
          ? int.parse(maximumSelections.text.trim())
          : null,
    );
  }
}

String trainerQuestionTypeLabel(TrainerFollowupQuestionType type) =>
    switch (type) {
      TrainerFollowupQuestionType.shortText => 'Texto corto',
      TrainerFollowupQuestionType.longText => 'Texto largo',
      TrainerFollowupQuestionType.number => 'Número',
      TrainerFollowupQuestionType.singleChoice => 'Una opción',
      TrainerFollowupQuestionType.multipleChoice => 'Varias opciones',
      TrainerFollowupQuestionType.scale => 'Escala',
      TrainerFollowupQuestionType.yesNo => 'Sí / No',
    };

class TrainerFormEditorPage extends StatefulWidget {
  const TrainerFormEditorPage({
    super.key,
    required this.repository,
    this.formId,
  });
  final TrainerFormRepository repository;
  final String? formId;
  @override
  State<TrainerFormEditorPage> createState() => _TrainerFormEditorPageState();
}

class _TrainerFormEditorPageState extends State<TrainerFormEditorPage> {
  final _title = TextEditingController(),
      _description = TextEditingController();
  final _questions = <_QuestionFields>[];
  final _operation = trainerOperationId();
  bool _loading = false, _saving = false, _dirty = false;
  String? _error;
  TrainerFollowupFormVersion? _initial, _pending;
  @override
  void initState() {
    super.initState();
    if (widget.formId == null) {
      _questions.add(_QuestionFields());
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final q in _questions) {
      // El EditableText de la pregunta debe desmontarse antes
      // de disponer sus controladores.
      WidgetsBinding.instance.addPostFrameCallback((_) => q.dispose());
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final form = await widget.repository.get(widget.formId!);
      if (!mounted) return;
      _initial = form;
      _title.text = form.title;
      _description.text = form.description ?? '';
      _questions.addAll(form.questions.map((q) => _QuestionFields(initial: q)));
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft =
          _pending ??
          TrainerFollowupValidator.normalizeForm(
            TrainerFollowupFormVersion(
              formId: _initial?.formId ?? _operation,
              versionId: _operation,
              revision: (_initial?.revision ?? 0) + 1,
              title: _title.text,
              description: _description.text,
              questions: [
                for (var i = 0; i < _questions.length; i++)
                  _questions[i].value(i),
              ],
            ),
          );
      _pending = draft;
      await widget.repository.save(
        _operation,
        draft,
        previousId: widget.formId,
      );
      if (mounted) {
        _dirty = false;
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/forms');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.formId == null ? 'Crear formulario' : 'Revisar formulario',
        ),
      ),
      bottomNavigationBar: ProfessionalWorkspaceScope.isDesktop(context)
          ? Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Align(
                    heightFactor: 1,
                    alignment: Alignment.centerRight,
                    child: _saveAction(),
                  ),
                ),
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(
            context,
            maxWidth: 850,
          ),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && widget.formId != null && _initial == null)
                TextButton(
                  onPressed: _load,
                  child: const Text('Reintentar carga'),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_pending != null)
                const Text(
                  'El guardado ya se ha enviado. Reintenta para confirmar exactamente el mismo contenido.',
                ),
              ExcludeFocus(
                excluding: _saving || _pending != null || _loading,
                child: AbsorbPointer(
                  absorbing: _saving || _pending != null || _loading,
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: 'Título'),
                        onChanged: (_) => _changed(),
                      ),
                      TextField(
                        controller: _description,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción opcional',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      ProfessionalCatalogGrid(
                        minCardWidth: 440,
                        maxColumns: 2,
                        children: [
                          for (var i = 0; i < _questions.length; i++)
                            _question(i),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _questions.length >= 40
                            ? null
                            : () => setState(() {
                                _questions.add(_QuestionFields());
                                _dirty = true;
                              }),
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir pregunta'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!ProfessionalWorkspaceScope.isDesktop(context))
                Align(alignment: Alignment.centerRight, child: _saveAction()),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _saveAction() => FilledButton(
    onPressed:
        _saving || _loading || (widget.formId != null && _initial == null)
        ? null
        : _save,
    child: Text(
      _saving
          ? 'Guardando…'
          : _pending != null
          ? 'Reintentar el mismo guardado'
          : 'Guardar versión',
    ),
  );

  Widget _question(int index) {
    final q = _questions[index];
    final choice =
        q.type == TrainerFollowupQuestionType.singleChoice ||
        q.type == TrainerFollowupQuestionType.multipleChoice;
    final numeric =
        q.type == TrainerFollowupQuestionType.number ||
        q.type == TrainerFollowupQuestionType.scale;
    return Card(
      key: ValueKey(q.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Pregunta ${index + 1}')),
                IconButton(
                  tooltip: 'Subir pregunta',
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          _questions.removeAt(index);
                          _questions.insert(index - 1, q);
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar pregunta',
                  onPressed: index == _questions.length - 1
                      ? null
                      : () => setState(() {
                          _questions.removeAt(index);
                          _questions.insert(index + 1, q);
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Eliminar pregunta',
                  onPressed: () => setState(() {
                    _questions.removeAt(index);
                    q.dispose();
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: q.prompt,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Pregunta'),
              onChanged: (_) => _changed(),
            ),
            DropdownButtonFormField<TrainerFollowupQuestionType>(
              initialValue: q.type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de respuesta'),
              items: TrainerFollowupQuestionType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(trainerQuestionTypeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (type) {
                if (type != null) {
                  setState(() {
                    q.type = type;
                    _dirty = true;
                  });
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obligatoria'),
              value: q.required,
              onChanged: (value) => setState(() {
                q.required = value;
                _dirty = true;
              }),
            ),
            TextField(
              controller: q.help,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Ayuda opcional'),
              onChanged: (_) => _changed(),
            ),
            if (choice)
              TextField(
                controller: q.options,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Opciones: una por línea',
                  helperText: 'Entre 2 y 20 opciones.',
                ),
                onChanged: (_) => _changed(),
              ),
            if (q.type == TrainerFollowupQuestionType.multipleChoice)
              TextField(
                controller: q.maximumSelections,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Máximo de opciones (opcional)',
                ),
                onChanged: (_) => _changed(),
              ),
            if (numeric)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: q.minimum,
                      decoration: InputDecoration(
                        labelText: q.type == TrainerFollowupQuestionType.scale
                            ? 'Mínimo (por defecto 1)'
                            : 'Mínimo opcional',
                      ),
                      onChanged: (_) => _changed(),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: q.maximum,
                      decoration: InputDecoration(
                        labelText: q.type == TrainerFollowupQuestionType.scale
                            ? 'Máximo (por defecto 5)'
                            : 'Máximo opcional',
                      ),
                      onChanged: (_) => _changed(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class TrainerClientFormsPage extends StatefulWidget {
  const TrainerClientFormsPage({
    super.key,
    required this.repository,
    required this.client,
  });
  final TrainerFormRepository repository;
  final TrainerClient client;
  @override
  State<TrainerClientFormsPage> createState() => _TrainerClientFormsPageState();
}

class _TrainerClientFormsPageState extends State<TrainerClientFormsPage> {
  List<TrainerFormAssignment> _items = [];
  bool _busy = true, _more = false;
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
      final rows = await widget.repository.assignments(
        widget.client.personId,
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    try {
      final forms = await widget.repository.list();
      if (!mounted) return;
      if (forms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crea primero un formulario.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AssignFormDialog(
          repository: widget.repository,
          relationId: widget.client.activeRelationId!,
          forms: forms,
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Formularios · ${widget.client.name}')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (widget.client.active)
          FilledButton(
            onPressed: _busy ? null : _assign,
            child: const Text('Asignar formulario'),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _error != null)
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        if (!_busy && _items.isEmpty && _error == null)
          const Text('No hay formularios asignados.'),
        for (final item in _items)
          Card(
            child: ListTile(
              title: Text(item.form.title),
              subtitle: Text(
                '${item.statusLabel} · Fecha ${_date(item.dueDate)} · v${item.form.revision}',
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(item.form.title),
                  content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final question in item.form.questions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '${question.prompt}\n${trainerFormAnswerLabel(question, item.answers?[question.id])}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Cargar anteriores'),
          ),
      ],
    ),
  );
}

String trainerFormAnswerLabel(TrainerFollowupQuestion q, Object? value) {
  if (value == null) return 'Sin respuesta';
  if (value is bool) return value ? 'Sí' : 'No';
  String option(Object? id) =>
      q.options.where((o) => o.id == id).firstOrNull?.label ?? '$id';
  if (value is List) return value.map(option).join(', ');
  if (q.type == TrainerFollowupQuestionType.singleChoice) return option(value);
  return '$value';
}

class _AssignFormDialog extends StatefulWidget {
  const _AssignFormDialog({
    required this.repository,
    required this.relationId,
    required this.forms,
  });
  final TrainerFormRepository repository;
  final String relationId;
  final List<TrainerFollowupFormVersion> forms;
  @override
  State<_AssignFormDialog> createState() => _AssignFormDialogState();
}

class _AssignFormDialogState extends State<_AssignFormDialog> {
  final _operation = trainerOperationId();
  late String _formId = widget.forms.first.versionId;
  DateTime _due = DateUtils.dateOnly(DateTime.now());
  bool _busy = false, _sent = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _sent = true;
      _error = null;
    });
    try {
      await widget.repository.assign(
        _operation,
        relationId: widget.relationId,
        formId: _formId,
        dueDate: _due,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = trainerFormError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Asignar formulario'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _formId,
                isExpanded: true,
                items: widget.forms
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.versionId,
                        child: Text(f.title),
                      ),
                    )
                    .toList(),
                onChanged: _sent ? null : (v) => setState(() => _formId = v!),
              ),
              TextButton(
                onPressed: _sent
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _due,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2200, 12, 31),
                        );
                        if (date != null && mounted) {
                          setState(() => _due = date);
                        }
                      },
                child: Text('Fecha: ${_date(_due)}'),
              ),
              if (_error != null) Text(_error!),
              if (_sent && !_busy)
                const Text('Reintenta para confirmar el mismo envío.'),
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
