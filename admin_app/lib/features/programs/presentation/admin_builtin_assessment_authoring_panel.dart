import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workout_editor_ui/guided_program_work.dart'
    show newGuidedWorkId;

import '../../operations/presentation/admin_editorial_diff.dart';
import '../data/admin_builtin_assessment_authoring_repository.dart';
import 'admin_builtin_assessment_authoring_preview.dart';
import 'admin_builtin_assessment_authoring_values.dart';

class AdminBuiltinAssessmentAuthoringPanel extends StatefulWidget {
  const AdminBuiltinAssessmentAuthoringPanel({
    super.key,
    required this.programId,
    required this.repository,
    this.onPublished,
  });
  final String programId;
  final AdminBuiltinAssessmentAuthoringRepository repository;
  final VoidCallback? onPublished;
  @override
  State<AdminBuiltinAssessmentAuthoringPanel> createState() =>
      _AdminBuiltinAssessmentAuthoringPanelState();
}

class _AdminBuiltinAssessmentAuthoringPanelState
    extends State<AdminBuiltinAssessmentAuthoringPanel> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _source = TextEditingController();
  final _effective = TextEditingController();
  final _reason = TextEditingController();
  AdminBuiltinAssessmentWorkspace? _workspace;
  AdminBuiltinAssessmentRevision? _selected;
  Map<String, dynamic>? _definition;
  AdminBuiltinAssessmentReview? _review;
  String? _savedSignature, _error, _notice, _requestId, _requestBase;
  int? _reviewEditVersion;
  bool _loading = true, _busy = false;
  int _generation = 0, _operation = 0;
  bool _current(int operation) => mounted && operation == _operation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant AdminBuiltinAssessmentAuthoringPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (widget.programId != oldWidget.programId ||
        widget.repository != oldWidget.repository) {
      _operation++;
      _busy = false;
      _workspace = null;
      _selected = null;
      _definition = null;
      _review = null;
      _requestId = null;
      _requestBase = null;
      _notice = null;
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _source, _effective, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _signature => jsonEncode([_definition, _reason.text.trim()]);
  bool get _dirty =>
      _selected?.isDraft == true && _signature != _savedSignature;
  bool get _canEdit => _selected?.isDraft == true && !_busy;
  bool get _canReview => _selected?.isDraft == true && !_dirty && !_busy;
  bool get _canPublish =>
      _canReview &&
      _review != null &&
      _review!.issues.isEmpty &&
      _reviewEditVersion == _selected!.editVersion;

  void _select(AdminBuiltinAssessmentRevision revision) {
    _selected = revision;
    _definition = copyBuiltinDefinition(revision.definition);
    _name.text = _definition!['name'] as String? ?? '';
    _description.text = _definition!['description'] as String? ?? '';
    _source.text = _definition!['sourceUrl'] as String? ?? '';
    _effective.text = _definition!['effectiveFrom'] as String? ?? '';
    _reason.text = revision.changeReason;
    _savedSignature = _signature;
    _review = null;
    _reviewEditVersion = null;
    _error = null;
  }

  Future<void> _load({String? selectId}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workspace = await widget.repository.workspace(widget.programId);
      if (!mounted || generation != _generation) return;
      final selected =
          workspace.revisions.where((r) => r.id == selectId).firstOrNull ??
          workspace.revisions.where((r) => r.isDraft).firstOrNull ??
          workspace.revisions
              .where((r) => r.id == workspace.currentRevisionId)
              .firstOrNull ??
          workspace.revisions.firstOrNull;
      setState(() {
        _workspace = workspace;
        if (selected != null) _select(selected);
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron consultar las versiones. Esto no significa que la preparación esté vacía.';
        });
      }
    }
  }

  void _changed() => setState(() {
    _definition!['name'] = _name.text;
    _definition!['description'] = _description.text;
    _definition!['sourceUrl'] = _source.text;
    _definition!['effectiveFrom'] = _effective.text;
    _review = null;
    _reviewEditVersion = null;
    _error = null;
    _notice = null;
  });

  Future<bool> _leaveChanges() async {
    if (!_dirty) return true;
    return await _confirm(
      '¿Cambiar de versión sin guardar?',
      'Se perderán únicamente los cambios de esta pantalla. El borrador guardado y las versiones publicadas se conservan.',
      'Cambiar sin guardar',
    );
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  String _failure(Object error, String fallback) {
    if (error is PostgrestException &&
        ['40001', '23505'].contains(error.code)) {
      return 'La versión cambió en otra pestaña. Tus cambios se conservan aquí; consulta la versión guardada antes de volver a intentarlo.';
    }
    if (error is PostgrestException &&
        ['22023', '42501', 'P0002'].contains(error.code)) {
      return error.message;
    }
    return fallback;
  }

  Future<void> _create(AdminBuiltinAssessmentRevision base) async {
    if (_busy || !await _leaveChanges() || !mounted) return;
    if (_requestBase != base.id) {
      _requestBase = base.id;
      _requestId = newGuidedWorkId();
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await widget.repository.createRevision(
        programId: widget.programId,
        baseId: base.id,
        requestId: _requestId!,
      );
      if (!_current(operation)) return;
      // Un reintento tras una respuesta perdida conserva el mismo request ID.
      _requestId = null;
      _requestBase = null;
      await _load(selectId: row.id);
      if (_current(operation)) {
        setState(
          () => _notice = 'Revisión en borrador preparada. La versión publicada se conserva.',
        );
      }
    } catch (error) {
      if (_current(operation)) {
        setState(
          () => _error = _failure(
            error,
            'No se pudo confirmar la creación. Reintenta desde esta pantalla; no se duplicará la solicitud.',
          ),
        );
      }
    } finally {
      if (_current(operation)) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_canEdit || !_form.currentState!.validate()) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await widget.repository.save(
        revision: _selected!,
        definition: copyBuiltinDefinition(_definition!),
        changeReason: _reason.text.trim(),
      );
      if (!_current(operation)) return;
      setState(() {
        _workspace = AdminBuiltinAssessmentWorkspace(
          currentRevisionId: _workspace!.currentRevisionId,
          revisions: [
            for (final item in _workspace!.revisions)
              item.id == row.id ? row : item,
          ],
        );
        _select(row);
        _notice = 'Borrador guardado. Todavía no está publicado.';
      });
    } catch (error) {
      if (_current(operation)) {
        setState(
          () => _error = _failure(
            error,
            'No se pudo guardar. Tus cambios se conservan; vuelve a intentarlo.',
          ),
        );
      }
    } finally {
      if (_current(operation)) setState(() => _busy = false);
    }
  }

  Future<void> _reviewSaved() async {
    if (!_canReview) return;
    final revision = _selected!;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
      _review = null;
      _reviewEditVersion = null;
    });
    try {
      final review = await widget.repository.review(revision.id);
      if (!_current(operation)) return;
      setState(() {
        _review = review;
        _reviewEditVersion = revision.editVersion;
      });
    } catch (error) {
      if (_current(operation)) {
        setState(
          () => _error = _failure(
            error,
            'No se pudo completar la revisión. El borrador sigue guardado.',
          ),
        );
      }
    } finally {
      if (_current(operation)) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    final revision = _selected!;
    if (!await _confirm(
          'Publicar revisión ${revision.revision}',
          'Se publicará este baremo para las nuevas preparaciones que le correspondan. Los resultados históricos y las preparaciones existentes conservan su versión. Las condiciones de entrenamiento no cambian.',
          'Publicar esta revisión',
        ) ||
        !mounted ||
        !_canPublish) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await widget.repository.publish(revision);
      if (!_current(operation)) return;
      await _load(selectId: row.id);
      if (_current(operation)) {
        setState(
          () => _notice = 'Revisión publicada. Las preparaciones existentes y su historial se conservan.',
        );
        widget.onPublished?.call();
      }
    } catch (error) {
      if (_current(operation)) {
        setState(() {
          _review = null;
          _reviewEditVersion = null;
          _error = _failure(
            error,
            'No se pudo confirmar la publicación. Actualiza las versiones antes de repetirla.',
          );
        });
      }
    } finally {
      if (_current(operation)) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (_busy || _selected?.status != 'published') return;
    final row = _selected!;
    if (!await _confirm(
          'Retirar revisión ${row.revision}',
          'Dejará de estar disponible para nuevas preparaciones. Sus resultados, las preparaciones que ya la utilizan y el historial se conservan.',
          'Retirar para nuevas preparaciones',
        ) ||
        !mounted) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final withdrawn = await widget.repository.withdraw(row);
      if (!_current(operation)) return;
      await _load(selectId: withdrawn.id);
      if (_current(operation)) {
        setState(
          () => _notice = 'Revisión retirada para nuevas preparaciones. El historial se conserva.',
        );
        widget.onPublished?.call();
      }
    } catch (error) {
      if (_current(operation)) {
        setState(
          () => _error = _failure(
            error,
            'No se pudo confirmar la retirada. Actualiza las versiones antes de repetirla.',
          ),
        );
      }
    } finally {
      if (_current(operation)) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_effective.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    _effective.text =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    _changed();
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Evaluación · versiones',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Edita una revisión en borrador, comprueba sus cambios y publícala al terminar. Las versiones utilizadas se conservan.',
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_notice != null) ...[const SizedBox(height: 12), Text(_notice!)],
        if (!_loading && _workspace == null)
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Reintentar versiones'),
          ),
        if (_workspace != null && _selected != null) ...[
          const SizedBox(height: 16),
          _history(),
          const SizedBox(height: 12),
          _actions(),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Revisión ${_selected!.revision} · ${_status(_selected!.status)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText('Catálogo: ${_selected!.catalogVersion}'),
                if (_selected!.isFas)
                  SelectableText('Puntuación: ${_selected!.scoringVersion}'),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('builtin-authoring-name'),
                  controller: _name,
                  readOnly: !_canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del catálogo',
                  ),
                  onChanged: (_) => _changed(),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Indica el nombre.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  readOnly: !_canEdit,
                  maxLines: null,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('builtin-authoring-source'),
                  controller: _source,
                  readOnly: !_canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Fuente normativa (enlace)',
                  ),
                  onChanged: (_) => _changed(),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri?.scheme != 'https' || (uri?.host.isEmpty ?? true)
                        ? 'Indica un enlace HTTPS válido.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _effective,
                  readOnly: true,
                  onTap: _canEdit ? _pickDate : null,
                  decoration: InputDecoration(
                    labelText: 'Vigencia desde (año-mes-día)',
                    suffixIcon: _canEdit
                        ? IconButton(
                            tooltip: 'Elegir fecha de vigencia',
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                          )
                        : null,
                  ),
                  validator: (value) => DateTime.tryParse(value ?? '') == null
                      ? 'Indica la fecha de vigencia.'
                      : null,
                ),
                if (_selected!.isDraft) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('builtin-authoring-reason'),
                    controller: _reason,
                    enabled: !_busy,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del cambio',
                    ),
                    onChanged: (_) => _changed(),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Explica el motivo antes de guardar.'
                        : null,
                  ),
                ] else if (_selected!.changeReason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Motivo: ${_selected!.changeReason}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final note in _definition!['sourceNotes'] as List? ?? [])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Nota de la fuente: $note'),
            ),
          if (_selected!.isFas)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Se conserva el mínimo de 20 puntos por prueba y las condiciones de edad. Las anomalías de la fuente no se corrigen automáticamente.',
              ),
            ),
          AdminBuiltinAssessmentValuesEditor(
            key: ValueKey('builtin-values-${_selected!.id}'),
            definition: _definition!,
            isFas: _selected!.isFas,
            enabled: _canEdit,
            onChanged: (definition) => setState(() {
              _definition = definition;
              _review = null;
              _reviewEditVersion = null;
              _notice = null;
            }),
          ),
          const SizedBox(height: 16),
          _comparison(),
          AdminBuiltinAssessmentPreview(
            key: ValueKey('builtin-simulator-${_selected!.id}'),
            revision: _selected!,
            repository: widget.repository,
            enabled: !_dirty && !_busy,
          ),
          if (_selected!.isDraft) ...[
            const SizedBox(height: 16),
            _reviewPanel(),
            const SizedBox(height: 12),
            _actions(bottom: true),
          ],
        ],
      ],
    ),
  );

  Widget _actions({bool bottom = false}) {
    final draft = _workspace!.revisions.where((r) => r.isDraft).firstOrNull;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (_selected!.isDraft) ...[
          FilledButton.icon(
            onPressed: _canEdit && _dirty ? _save : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar borrador'),
          ),
          OutlinedButton.icon(
            onPressed: _canReview ? _reviewSaved : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Revisar antes de publicar'),
          ),
          if (bottom)
            FilledButton.icon(
              onPressed: _canPublish ? _publish : null,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Publicar revisión'),
            ),
        ] else ...[
          if (draft != null)
            FilledButton.icon(
              onPressed: _busy ? null : () => setState(() => _select(draft)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Retomar borrador'),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _create(_selected!),
            icon: const Icon(Icons.copy_outlined),
            label: Text(
              _selected!.id == _workspace!.currentRevisionId
                  ? 'Crear revisión'
                  : 'Recuperar como borrador',
            ),
          ),
          if (_selected!.status == 'published')
            TextButton.icon(
              onPressed: _busy ? null : _withdraw,
              icon: const Icon(Icons.unpublished_outlined),
              label: const Text('Retirar para nuevas preparaciones'),
            ),
        ],
        if (!bottom)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    if (await _leaveChanges() && mounted) {
                      await _load(selectId: _selected?.id);
                    }
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar versiones'),
          ),
      ],
    );
  }

  Widget _history() => ExpansionTile(
    key: PageStorageKey('builtin-history-${widget.programId}'),
    title: const Text('Versiones e historial'),
    subtitle: Text('${_workspace!.revisions.length} revisiones conservadas'),
    children: [
      for (final row in _workspace!.revisions)
        ListTile(
          title: Text(
            'Revisión ${row.revision} · ${_status(row.status)}${row.id == _workspace!.currentRevisionId ? ' · actual para nuevas preparaciones' : ''}',
          ),
          subtitle: Text(
            '${row.definition['name'] ?? ''}${row.changeReason.isEmpty ? '' : '\n${row.changeReason}'}${_dateLabel(row).isEmpty ? '' : '\n${_dateLabel(row)}'}',
          ),
          selected: _selected!.id == row.id,
          onTap: _busy
              ? null
              : () async {
                  if (row.id == _selected!.id ||
                      !await _leaveChanges() ||
                      !mounted) {
                    return;
                  }
                  setState(() {
                    _select(row);
                    _notice = null;
                  });
                },
        ),
    ],
  );

  String _dateLabel(AdminBuiltinAssessmentRevision row) {
    final date = DateTime.tryParse(row.publishedAt ?? row.createdAt ?? '')
        ?.toLocal();
    if (date == null) return '';
    final labels = MaterialLocalizations.of(context);
    return '${row.publishedAt == null ? 'Creada' : 'Publicada'}: ${labels.formatMediumDate(date)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  Widget _comparison() {
    final base = _workspace!.revisions
        .where((r) => r.id == _selected!.baseId)
        .firstOrNull;
    if (base == null) return const SizedBox.shrink();
    final diffs = editorialDifferences(base.definition, _definition);
    return ExpansionTile(
      key: PageStorageKey('builtin-comparison-${_selected!.id}'),
      title: const Text('Comparar con la versión de origen'),
      subtitle: Text(
        'Origen: revisión ${base.revision}${_dirty ? ' · incluye cambios sin guardar' : ''}',
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        if (diffs.isEmpty) const Text('Sin diferencias de contenido.'),
        if (diffs.length == 200)
          const Text(
            'Se muestran hasta 200 diferencias. La revisión del servidor comprueba la definición completa.',
          ),
        for (final diff in diffs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_path(diff.path)),
                Text('Antes: ${diff.before}'),
                Text('Ahora: ${diff.after}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisión antes de publicar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_dirty)
            const Text(
              'Guarda los cambios para revisar y publicar exactamente esa versión.',
            ),
          if (!_dirty && _review == null)
            const Text(
              'Ejecuta la revisión del borrador guardado antes de publicar.',
            ),
          if (_review != null) ...[
            Text(
              _review!.issues.isEmpty
                  ? 'Sin errores bloqueantes en la revisión del servidor.'
                  : 'Resuelve los errores antes de publicar.',
            ),
            for (final issue in _review!.issues)
              Text(
                issue,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final warning in _review!.warnings) Text('Aviso: $warning'),
            Text('${_review!.changeCount} cambios detectados.'),
            Text(
              '${_review!.existingGoalsPreserved} preparaciones existentes conservarán su configuración.',
            ),
            const Text(
              'Comprueba la fuente, la vigencia y el simulador. La validación técnica no confirma por sí sola la corrección normativa.',
            ),
          ],
        ],
      ),
    ),
  );
}

String _status(String value) => switch (value) {
  'draft' => 'Borrador',
  'published' => 'Publicada',
  'withdrawn' => 'Retirada',
  _ => value,
};

String _path(String raw) {
  var text = raw;
  for (final entry in {
    'sourceUrl': 'Fuente',
    'effectiveFrom': 'Vigencia',
    'tests': 'Pruebas',
    'standards': 'Mínimos',
    'threshold': 'Marca mínima',
    'rows': 'Filas de puntuación',
    'category': 'Sexo',
    'group': 'Hito',
    'testId': 'Prueba',
  }.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}
