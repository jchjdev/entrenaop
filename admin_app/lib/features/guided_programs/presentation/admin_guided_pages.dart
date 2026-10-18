import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../domain/admin_guided_repository.dart';
import '../../editorial_covers/domain/program_cover.dart';
import '../../editorial_covers/presentation/program_cover_editor.dart';

class AdminGuidedCatalogPage extends StatefulWidget {
  const AdminGuidedCatalogPage({
    super.key,
    required this.repository,
    this.warmups = false,
    this.covers,
  });
  final AdminGuidedRepository repository;
  final bool warmups;
  final ProgramCoverRepository? covers;
  @override
  State<AdminGuidedCatalogPage> createState() => _AdminGuidedCatalogPageState();
}

class _AdminGuidedCatalogPageState extends State<AdminGuidedCatalogPage> {
  List<GuidedProgram>? _programs;
  List<GuidedWarmup>? _warmups;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.warmups) {
        final items = await widget.repository.warmups();
        if (mounted) {
          setState(() {
            _warmups = items;
            _error = null;
          });
        }
      } else {
        final items = await widget.repository.programs();
        if (mounted) {
          setState(() {
            _programs = items;
            _error = null;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el catálogo.');
    }
  }

  Future<void> _open(String suffix) async {
    await context.push(
      '${widget.warmups ? '/warmups' : '/guided-programs'}/$suffix',
    );
    if (mounted) await _load();
  }

  Future<void> _status(GuidedProgram p, String status) async {
    setState(() => _busy = true);
    try {
      await widget.repository.setStatus(p.id!, status);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo cambiar el estado. Revisa que las sesiones y calentamientos sigan publicados.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cover(GuidedProgram p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ProgramCoverEditor(
          programId: p.id!,
          programName: p.name,
          repository: widget.covers!,
          editorTitle: 'Imagen del programa',
          headerTitle: 'Cabecera del programa',
          cardLabel: p.modeLabel,
          cardDetail: '${p.sessionCount} sesiones',
          cardAction: 'Ver programa →',
          cardIcon: p.mode == GuidedProgramMode.guide
              ? Icons.fitness_center_rounded
              : Icons.trending_up_rounded,
          squareCard: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.warmups ? 'Calentamientos' : 'Programas guiados'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/programs'),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.warmups
                  ? 'Calentamientos reutilizables'
                  : 'Rutinas y programas por fases',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              widget.warmups
                  ? 'Cada guardado conserva una versión. Puedes asignarla a varias sesiones.'
                  : 'Un único creador para ambos recorridos. Publicar los incorpora al catálogo; no activa planes adaptativos.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _open('new'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    widget.warmups
                        ? 'Crear calentamiento'
                        : 'Crear programa guiado',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push(
                    widget.warmups ? '/guided-programs' : '/warmups',
                  ),
                  child: Text(
                    widget.warmups
                        ? 'Programas guiados'
                        : 'Gestionar calentamientos',
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (_programs == null && _warmups == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            for (final p in _programs ?? <GuidedProgram>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${p.modeLabel} · v${p.version} · ${p.status == 'draft'
                            ? 'Borrador'
                            : p.status == 'published'
                            ? 'Publicado'
                            : 'Retirado'}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.covers != null)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _cover(p),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Portada'),
                            ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _open('${p.id}/edit'),
                            child: Text(
                              p.status == 'draft'
                                  ? 'Editar borrador'
                                  : 'Crear revisión',
                            ),
                          ),
                          if (p.status == 'draft')
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _status(p, 'published'),
                              child: const Text('Publicar'),
                            ),
                          if (p.status == 'published')
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _status(p, 'archived'),
                              child: const Text('Retirar del catálogo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            for (final w in _warmups ?? <GuidedWarmup>[])
              Card(
                child: ListTile(
                  title: Text(w.name),
                  subtitle: Text('Versión ${w.version}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _open('${w.id}/edit'),
                ),
              ),
            if (_programs?.isEmpty == true || _warmups?.isEmpty == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Todavía no hay contenido. Crea el primero desde aquí.',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AdminGuidedEditorPage extends StatefulWidget {
  const AdminGuidedEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    this.original,
  });
  final AdminGuidedRepository repository;
  final AdminWorkoutRepository workouts;
  final GuidedProgram? original;
  @override
  State<AdminGuidedEditorPage> createState() => _AdminGuidedEditorPageState();
}

class _AdminGuidedEditorPageState extends State<AdminGuidedEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _audience = TextEditingController(),
      _equipment = TextEditingController();
  GuidedProgramMode _mode = GuidedProgramMode.guide;
  final _phases = <_PhaseFields>[];
  List<AdminWorkoutSummary> _sessions = [];
  List<GuidedWarmup> _warmups = [];
  bool _busy = false, _loading = true, _dirty = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.original;
    _name.text = p?.name ?? '';
    _description.text = p?.description ?? '';
    _audience.text = p?.audience ?? '';
    _equipment.text = p?.equipment ?? '';
    _mode = p?.mode ?? GuidedProgramMode.guide;
    _phases.addAll(p?.phases.map(_PhaseFields.fromPhase) ?? [_PhaseFields()]);
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await widget.workouts.listGeneral();
      final warmups = await widget.repository.warmups();
      if (mounted) {
        setState(() {
          _sessions = sessions.where((s) => s.status == 'published').toList();
          _warmups = warmups;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar las sesiones o calentamientos.';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _audience, _equipment]) {
      c.dispose();
    }
    for (final p in _phases) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _addSession(_PhaseFields phase) async {
    final selected = await showDialog<AdminWorkoutSummary>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir sesión oficial'),
        content: SizedBox(
          width: 480,
          child: _sessions.isEmpty
              ? const Text(
                  'Publica primero una sesión desde Sesiones oficiales.',
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in _sessions)
                      ListTile(
                        title: Text(s.name),
                        subtitle: Text('Versión ${s.version}'),
                        onTap: () => Navigator.pop(ctx, s),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        phase.sessions.add(_SessionFields(selected.id, selected.name));
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      final p = GuidedProgram(
        name: _name.text,
        description: _description.text,
        audience: _audience.text,
        equipment: _equipment.text,
        mode: _mode,
        phases: _phases.map((p) => p.input(_mode)).toList(),
      );
      validateGuidedProgram(p);
      setState(() {
        _busy = true;
        _error = null;
      });
      await widget.repository.save(p, id: widget.original?.id);
      if (mounted) {
        setState(() => _dirty = false);
        context.pop(true);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Comprueba las sesiones publicadas, los descansos y la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    bool required = false,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => _dirty = true,
      validator: (v) =>
          required && (v ?? '').trim().isEmpty ? 'Completa este campo.' : null,
    ),
  );
  void _movePhase(int i, int delta) => setState(() {
    final p = _phases.removeAt(i);
    _phases.insert(i + delta, p);
    _dirty = true;
  });
  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.original == null
              ? 'Crear programa guiado'
              : 'Editar programa guiado',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _busy,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _field(_name, 'Nombre del programa', required: true),
                        _field(
                          _description,
                          'Objetivo e indicaciones',
                          lines: 3,
                        ),
                        _field(
                          _audience,
                          'Destinatarios y requisitos',
                          lines: 2,
                        ),
                        _field(_equipment, 'Material necesario'),
                        SegmentedButton<GuidedProgramMode>(
                          segments: const [
                            ButtonSegment(
                              value: GuidedProgramMode.guide,
                              label: Text('Rutina'),
                            ),
                            ButtonSegment(
                              value: GuidedProgramMode.phased,
                              label: Text('Por fases'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (v) {
                            if (v.first == GuidedProgramMode.guide &&
                                _phases.length > 1) {
                              setState(
                                () => _error = 'Conserva una sola fase antes de convertirlo en rutina.',
                              );
                              return;
                            }
                            setState(() {
                              _mode = v.first;
                              _dirty = true;
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _mode == GuidedProgramMode.guide
                              ? 'Las sesiones se pueden repetir sin fecha de finalización.'
                              : 'El usuario confirma el paso de fase; el calendario no lo hace avanzar.',
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _phases.length; i++)
                          _phaseCard(_phases[i], i),
                        if (_mode == GuidedProgramMode.phased)
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _phases.add(_PhaseFields());
                              _dirty = true;
                            }),
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir fase'),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                await context.push('/sessions/new');
                                if (mounted) await _load();
                              },
                              child: const Text('Crear sesión oficial'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                await context.push('/warmups/new');
                                if (mounted) await _load();
                              },
                              child: const Text('Crear calentamiento'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/sessions'),
                              child: const Text('Publicar o revisar sesiones'),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _busy ? 'Guardando…' : 'Guardar borrador',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
  Widget _phaseCard(_PhaseFields p, int index) => Card(
    key: ValueKey(p),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mode == GuidedProgramMode.phased) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fase ${index + 1}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Subir fase',
                  onPressed: index == 0 ? null : () => _movePhase(index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar fase',
                  onPressed: index == _phases.length - 1
                      ? null
                      : () => _movePhase(index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                if (_phases.length > 1)
                  IconButton(
                    tooltip: 'Quitar fase',
                    onPressed: () => setState(() {
                      _phases.removeAt(index).dispose();
                      _dirty = true;
                    }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            _field(p.name, 'Nombre de la fase', required: true),
            _field(
              p.weeks,
              'Duración orientativa (semanas)',
              numeric: true,
              required: true,
            ),
            _field(
              p.instructions,
              'Indicaciones y condiciones de avance',
              lines: 3,
              required: true,
            ),
          ] else
            Text(
              'Sesiones del programa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.sessions.length; i++) _sessionCard(p, i),
          OutlinedButton.icon(
            onPressed: () => _addSession(p),
            icon: const Icon(Icons.add),
            label: const Text('Añadir sesión'),
          ),
        ],
      ),
    ),
  );
  Widget _sessionCard(_PhaseFields p, int i) {
    final s = p.sessions[i];
    return Card(
      key: ValueKey(s),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${i + 1}. ${s.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Subir sesión',
                  onPressed: i == 0
                      ? null
                      : () => setState(() {
                          p.sessions.removeAt(i);
                          p.sessions.insert(i - 1, s);
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Quitar sesión',
                  onPressed: () => setState(() {
                    p.sessions.removeAt(i).dispose();
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: s.warmup ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Calentamiento adjunto',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Sin calentamiento adjunto'),
                ),
                for (final w in _warmups)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text(
                      '${w.name} · v${w.version}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                s.warmup = v == '' ? null : v;
                _dirty = true;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir ajustar descansos entre series'),
              subtitle: const Text(
                'Solo bloques convencionales; se conservan los formatos temporizados.',
              ),
              value: s.adjustable,
              onChanged: (v) => setState(() {
                s.adjustable = v;
                _dirty = true;
              }),
            ),
            if (s.adjustable) ...[
              _field(
                s.minimum,
                'Descanso mínimo (segundos)',
                numeric: true,
                required: true,
              ),
              _field(
                s.maximum,
                'Descanso máximo (segundos)',
                numeric: true,
                required: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionFields {
  _SessionFields(this.id, this.name, {this.warmup});
  factory _SessionFields.fromSession(GuidedSession s) =>
      _SessionFields(s.templateId, s.name, warmup: s.warmupId)
        ..adjustable = s.restPolicy.adjustable
        ..minimum.text = '${s.restPolicy.minimumSeconds ?? 60}'
        ..maximum.text = '${s.restPolicy.maximumSeconds ?? 180}';
  final String id, name;
  String? warmup;
  bool adjustable = false;
  final minimum = TextEditingController(text: '60'),
      maximum = TextEditingController(text: '180');
  GuidedSession input() {
    final min = int.tryParse(minimum.text), max = int.tryParse(maximum.text);
    if (adjustable && (min == null || max == null)) {
      throw const FormatException('Escribe los descansos en segundos enteros.');
    }
    return GuidedSession(
      templateId: id,
      name: name,
      warmupId: warmup,
      restPolicy: GuidedRestPolicy(
        minimumSeconds: adjustable ? min : null,
        maximumSeconds: adjustable ? max : null,
      ),
    );
  }

  void dispose() {
    minimum.dispose();
    maximum.dispose();
  }
}

class _PhaseFields {
  _PhaseFields();
  factory _PhaseFields.fromPhase(GuidedPhase p) => _PhaseFields()
    ..name.text = p.name
    ..weeks.text = '${p.durationWeeks ?? 2}'
    ..instructions.text = p.instructions
    ..sessions.addAll(p.sessions.map(_SessionFields.fromSession));
  final name = TextEditingController(text: 'Entrenamiento'),
      weeks = TextEditingController(text: '2'),
      instructions = TextEditingController();
  final sessions = <_SessionFields>[];
  GuidedPhase input(GuidedProgramMode mode) => GuidedPhase(
    name: mode == GuidedProgramMode.guide ? 'Entrenamiento' : name.text,
    durationWeeks: mode == GuidedProgramMode.guide
        ? null
        : int.tryParse(weeks.text),
    instructions: instructions.text,
    sessions: sessions.map((s) => s.input()).toList(),
  );
  void dispose() {
    name.dispose();
    weeks.dispose();
    instructions.dispose();
    for (final s in sessions) {
      s.dispose();
    }
  }
}
