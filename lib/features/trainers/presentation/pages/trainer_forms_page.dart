import 'dart:math';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_followup.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

String _error(Object error) =>
    error is FormatException ? error.message : trainerError(error);
String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

class TrainerStudentFormsPage extends StatefulWidget {
  const TrainerStudentFormsPage({super.key, required this.repository});
  final TrainerStudentFormRepository repository;
  @override
  State<TrainerStudentFormsPage> createState() =>
      _TrainerStudentFormsPageState();
}

class _TrainerStudentFormsPageState extends State<TrainerStudentFormsPage> {
  List<TrainerFormAssignment> _items = [];
  bool _busy = true, _more = false;
  String? _message;
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
      final rows = await widget.repository.mine(
        before: more ? _items.last : null,
      );
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...rows] : rows;
          _more = rows.length == 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Formularios de mi preparador'),
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
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_message != null)
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Reintentar'),
              ),
            if (!_busy && _message == null && _items.isEmpty)
              const Text('No tienes formularios asignados.'),
            for (final item in _items)
              Card(
                child: ListTile(
                  title: Text(item.form.title),
                  subtitle: Text(
                    '${item.trainerName} · ${item.statusLabel}\nFecha ${_date(item.dueDate)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () async {
                    await context.push('/my-trainer/forms/${item.id}');
                    if (mounted) await _load();
                  },
                ),
              ),
            if (_more)
              TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Cargar anteriores'),
              ),
          ],
        ),
      ),
    ),
  );
}

class TrainerStudentFormPage extends StatefulWidget {
  const TrainerStudentFormPage({
    super.key,
    required this.repository,
    required this.assignmentId,
  });
  final TrainerStudentFormRepository repository;
  final String assignmentId;
  @override
  State<TrainerStudentFormPage> createState() => _TrainerStudentFormPageState();
}

class _TrainerStudentFormPageState extends State<TrainerStudentFormPage> {
  final _answers = <String, Object?>{};
  final _controllers = <String, TextEditingController>{};
  final _operation = _operationId();
  TrainerFormAssignment? _assignment;
  Map<String, Object?>? _pending;
  bool _loading = true, _saving = false, _dirty = false, _confirmed = false;
  String? _message;
  static String _operationId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final assignment = await widget.repository.assignment(
        widget.assignmentId,
      );
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _answers.addAll(assignment.answers ?? {});
        if (assignment.submittedAt != null) {
          _confirmed = true;
          _pending = null;
          _dirty = false;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving || _assignment == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final normalized = TrainerFollowupValidator.normalizeSubmission(
        form: _assignment!.form,
        versionId: _assignment!.form.versionId,
        answers: _pending ?? _answers,
      );
      _pending = normalized.answers;
      await widget.repository.submit(_operation, _assignment!, _pending!);
      if (!mounted) return;
      _dirty = false;
      _pending = null;
      _confirmed = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _set(String id, Object? value) => setState(() {
    _answers[id] = value;
    _dirty = true;
  });
  @override
  Widget build(BuildContext context) {
    final assignment = _assignment;
    final readonly =
        assignment == null ||
        !assignment.canRespond ||
        _confirmed ||
        assignment.submittedAt != null;
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _dirty,
      isBusy: () => _saving,
      child: Scaffold(
        appBar: AppBar(title: Text(assignment?.form.title ?? 'Formulario')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_message != null)
                  Text(
                    _message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!_loading && assignment == null)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar carga'),
                  ),
                if (assignment != null) ...[
                  Text(
                    '${assignment.trainerName} · Fecha ${_date(assignment.dueDate)} · Versión ${assignment.form.revision}',
                  ),
                  if (assignment.form.description != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(assignment.form.description!),
                    ),
                  if (assignment.submittedAt != null || _confirmed)
                    const Text('Respuesta enviada. Puedes consultarla aquí.'),
                  if (readonly && assignment.submittedAt == null && !_confirmed)
                    const Text(
                      'El servicio está inactivo. No se pueden enviar respuestas nuevas.',
                    ),
                  if (_pending != null)
                    const Text(
                      'Reintenta para confirmar exactamente las respuestas enviadas.',
                    ),
                  AbsorbPointer(
                    absorbing: readonly || _saving || _pending != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final question in assignment.form.questions)
                          _question(
                            question,
                            readonly || _saving || _pending != null,
                          ),
                      ],
                    ),
                  ),
                  if (!readonly)
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        _saving
                            ? 'Enviando…'
                            : _pending == null
                            ? 'Enviar respuestas'
                            : 'Reintentar el mismo envío',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(TrainerFollowupQuestion q, bool readonly) {
    final value = _answers[q.id];
    final label = '${q.prompt}${q.required ? ' *' : ''}';
    Widget control;
    switch (q.type) {
      case TrainerFollowupQuestionType.shortText:
      case TrainerFollowupQuestionType.longText:
      case TrainerFollowupQuestionType.number:
        final numeric = q.type == TrainerFollowupQuestionType.number;
        final controller = _controllers.putIfAbsent(
          q.id,
          () => TextEditingController(text: value?.toString() ?? ''),
        );
        control = TextField(
          key: ValueKey(q.id),
          controller: controller,
          readOnly: readonly,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.multiline,
          maxLines: q.type == TrainerFollowupQuestionType.longText ? 5 : 1,
          maxLength: numeric
              ? 32
              : q.type == TrainerFollowupQuestionType.shortText
              ? 240
              : 2000,
          decoration: InputDecoration(labelText: label, helperText: q.help),
          onChanged: (text) => _set(q.id, text),
        );
      case TrainerFollowupQuestionType.yesNo:
        control = DropdownButtonFormField<bool>(
          initialValue: value as bool?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, helperText: q.help),
          items: const [
            DropdownMenuItem(value: true, child: Text('Sí')),
            DropdownMenuItem(value: false, child: Text('No')),
          ],
          onChanged: readonly ? null : (selected) => _set(q.id, selected),
        );
      case TrainerFollowupQuestionType.scale:
        control = DropdownButtonFormField<int>(
          initialValue: value as int?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, helperText: q.help),
          items: [
            for (var i = q.minimum!.toInt(); i <= q.maximum!.toInt(); i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: readonly ? null : (selected) => _set(q.id, selected),
        );
      case TrainerFollowupQuestionType.singleChoice:
        control = DropdownButtonFormField<String>(
          initialValue: value as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, helperText: q.help),
          items: q.options
              .map((o) => DropdownMenuItem(value: o.id, child: Text(o.label)))
              .toList(),
          onChanged: readonly ? null : (selected) => _set(q.id, selected),
        );
      case TrainerFollowupQuestionType.multipleChoice:
        final selected = (value as List?)?.cast<String>() ?? <String>[];
        control = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label),
            if (q.help != null) Text(q.help!),
            for (final option in q.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                value: selected.contains(option.id),
                onChanged: readonly
                    ? null
                    : (checked) {
                        final next = selected.toSet();
                        if (checked == true) {
                          next.add(option.id);
                        } else {
                          next.remove(option.id);
                        }
                        _set(q.id, next.toList());
                      },
              ),
          ],
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: control,
    );
  }
}
