import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';

import '../../../core/admin_shell.dart';
import '../../../core/catalog_search.dart';

import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../domain/admin_guided_repository.dart';
import '../domain/admin_guided_work.dart';
import '../../editorial_covers/domain/program_cover.dart';
import '../../editorial_covers/presentation/program_cover_editor.dart';
import 'guided_category_editor.dart';
import 'admin_guided_program_card.dart';
import 'guided_session_picker.dart';

class AdminGuidedCatalogPage extends StatefulWidget {
  const AdminGuidedCatalogPage({
    super.key,
    required this.repository,
    this.warmups = false,
    this.covers,
    this.workRepository,
  });
  final AdminGuidedRepository repository;
  final bool warmups;
  final ProgramCoverRepository? covers;
  final AdminGuidedWorkRepository? workRepository;
  @override
  State<AdminGuidedCatalogPage> createState() => _AdminGuidedCatalogPageState();
}

class _AdminGuidedCatalogPageState extends State<AdminGuidedCatalogPage> {
  List<GuidedProgram>? _programs;
  List<GuidedWarmup>? _warmups;
  String? _error;
  bool _busy = false;
  List<GuidedWork> _work = [];
  String? _workError;
  final _search = TextEditingController();
  GuidedProgramMode? _mode;
  String _statusFilter = 'all';

  List<GuidedProgram> get _visiblePrograms => (_programs ?? <GuidedProgram>[])
      .where(
        (p) =>
            (_mode == null || p.mode == _mode) &&
            (_statusFilter == 'all' || p.status == _statusFilter) &&
            matchesCatalogSearch(_search.text, [
              p.name,
              p.description,
              p.audience,
              p.equipment,
              ...p.categories.map((c) => c.name),
            ]),
      )
      .toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
        try {
          _work = await widget.workRepository?.list() ?? [];
          _workError = null;
        } catch (_) {
          _workError = 'No se pudieron cargar tus borradores de trabajo. Pulsa Actualizar para reintentar.';
        }
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
    if (_busy) return;
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
          cardCategory: p.primaryCategory?.name,
          cardDetail: '${p.sessionCount} sesiones',
          cardAction: 'Ver programa →',
          cardIcon: p.mode == GuidedProgramMode.guide
              ? Icons.fitness_center_rounded
              : Icons.trending_up_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(
            title: Text(
              widget.warmups ? 'Calentamientos' : 'Programas guiados',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/programs'),
            ),
          ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.warmups
                  ? 'Calentamientos reutilizables'
                  : 'Programas guiados',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              widget.warmups
                  ? 'Cada guardado conserva una versión. Puedes asignarla a varias sesiones.'
                  : 'Organiza sesiones del catálogo en rutinas repetibles o recorridos por fases.',
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
                if (!AdminShellScope.hidesAppBar(context))
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
                if (!widget.warmups)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            await manageGuidedCategories(
                              context,
                              widget.repository,
                            );
                            if (mounted) await _load();
                          },
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Categorías'),
                  ),
                if (!widget.warmups)
                  IconButton.outlined(
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.warmups && widget.workRepository != null) ...[
              if (_workError != null) Text(_workError!),
              if (_work.isNotEmpty) ...[
                Text(
                  'Continuar trabajando',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Borradores privados, todavía fuera del catálogo. Se conservan aunque estén incompletos.',
                ),
                for (final work in _work)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            work.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (work.updatedAt != null)
                            Text(
                              'Guardado: ${work.updatedAt!.toLocal().toString().substring(0, 16)}',
                            ),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _open('work/${work.id}'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Continuar'),
                              ),
                              TextButton(
                                onPressed: _busy ? null : () => _discard(work),
                                child: const Text('Descartar trabajo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ],
            if (!widget.warmups) ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar programas',
                  hintText: 'Nombre, categoría o descripción',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (mode, label) in <(GuidedProgramMode?, String)>[
                    (null, 'Todos'),
                    (GuidedProgramMode.guide, 'Rutinas'),
                    (GuidedProgramMode.phased, 'Por fases'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Todos los estados'),
                        ),
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Borradores'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Publicados'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Retirados'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_programs?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_visiblePrograms.length} de ${_programs!.length} programas · ${_programs!.where((p) => p.status == 'published').length} publicados · ${_programs!.where((p) => p.status == 'draft').length} borradores',
                  ),
                ),
            ],
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (_programs == null && _warmups == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_programs?.isNotEmpty == true && _visiblePrograms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No hay programas con esta búsqueda y filtros.'),
              ),
            for (final p in _visiblePrograms)
              AdminGuidedProgramCard(
                program: p,
                onEdit: _busy ? null : () => _open('${p.id}/edit'),
                onPublish: _busy ? null : () => _status(p, 'published'),
                onRetire: _busy ? null : () => _status(p, 'archived'),
                onCover: widget.covers == null || _busy
                    ? null
                    : () => _cover(p),
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

  Future<void> _discard(GuidedWork work) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar este trabajo?'),
        content: const Text(
          'Se quitará de la lista. Las sesiones del catálogo y el programa de origen se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.workRepository!.discard(work);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _workError = 'No se pudo descartar. Actualiza el catálogo antes de reintentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class AdminGuidedEditorPage extends StatefulWidget {
  const AdminGuidedEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    this.original,
    this.workRepository,
    this.work,
  });
  final AdminGuidedRepository repository;
  final AdminWorkoutRepository workouts;
  final GuidedProgram? original;
  final AdminGuidedWorkRepository? workRepository;
  final GuidedWork? work;
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
  List<GuidedProgramCategory> _categories = [];
  final _categoryIds = <String>{};
  String? _primaryCategoryId;
  bool _catalogsReady = false;
  bool _busy = false, _loading = true, _dirty = false;
  String? _error;
  GuidedWorkController? _checkpoint;
  Timer? _saveTimer;
  GuidedProgram? _finalAttempt;
  @override
  void initState() {
    super.initState();
    final p = widget.original;
    _name.text = p?.name ?? '';
    _description.text = p?.description ?? '';
    _audience.text = p?.audience ?? '';
    _equipment.text = p?.equipment ?? '';
    _mode = p?.mode ?? GuidedProgramMode.guide;
    _categoryIds.addAll(p?.categories.map((c) => c.id) ?? const []);
    _primaryCategoryId = p?.primaryCategoryId;
    _phases.addAll(p?.phases.map(_PhaseFields.fromPhase) ?? [_PhaseFields()]);
    final work = widget.work;
    if (work != null && widget.workRepository != null) {
      if (work.state.isNotEmpty) _restore(work.state);
      _checkpoint = GuidedWorkController(
        widget.workRepository!,
        work,
        _snapshot(),
      )..addListener(_checkpointChanged);
    }
    _load();
  }

  Map<String, dynamic> _snapshot() => {
    'schema': 1,
    'name': _name.text,
    'description': _description.text,
    'audience': _audience.text,
    'equipment': _equipment.text,
    'mode': _mode.name,
    'categories': _categoryIds.toList(),
    'primary': _primaryCategoryId,
    'phases': _phases.map((p) => p.snapshot()).toList(),
  };
  void _restore(Map<String, dynamic> state) {
    if (state['schema'] != 1) {
      throw const FormatException(
        'Este borrador necesita otra versión del admin.',
      );
    }
    _name.text = state['name'] as String;
    _description.text = state['description'] as String;
    _audience.text = state['audience'] as String;
    _equipment.text = state['equipment'] as String;
    _mode = GuidedProgramMode.values.byName(state['mode'] as String);
    _categoryIds
      ..clear()
      ..addAll((state['categories'] as List).cast<String>());
    _primaryCategoryId = state['primary'] as String?;
    for (final p in _phases) {
      p.dispose();
    }
    _phases
      ..clear()
      ..addAll(
        (state['phases'] as List).map(
          (p) => _PhaseFields.restore(Map<String, dynamic>.from(p as Map)),
        ),
      );
  }

  void _checkpointChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    _dirty = true;
    if (_checkpoint == null) return;
    _saveTimer?.cancel();
    // Se captura después de completar la mutación de campos/listas del evento.
    _saveTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted || _finalAttempt != null) return;
      await _saveWork();
    });
  }

  Future<bool> _saveWork() async {
    final checkpoint = _checkpoint;
    if (checkpoint == null) return true;
    _saveTimer?.cancel();
    checkpoint.update(_snapshot());
    try {
      await checkpoint.flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _workStatus() {
    final checkpoint = _checkpoint!;
    final message = checkpoint.conflict
        ? 'Otra pestaña ha cambiado este trabajo. Tus campos siguen aquí. Abre el borrador actualizado antes de continuar.'
        : checkpoint.error != null
        ? 'No se ha guardado el último cambio. Conserva esta pantalla y reintenta.'
        : checkpoint.saving
        ? 'Guardando trabajo…'
        : _saveTimer?.isActive == true || checkpoint.dirty
        ? 'Cambios pendientes de guardar'
        : checkpoint.work.revision == 0
        ? 'Empieza a escribir para guardar tu trabajo automáticamente'
        : 'Trabajo guardado · puedes continuar más tarde desde Programas guiados';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (!checkpoint.conflict)
              TextButton.icon(
                onPressed: checkpoint.saving ? null : _saveWork,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Guardar trabajo ahora'),
              ),
            if (checkpoint.conflict)
              TextButton(
                onPressed: () => context.push('/guided-programs'),
                child: const Text('Abrir programas'),
              ),
            const Text(
              'Este guardado admite campos incompletos. «Guardar en catálogo» comprueba las sesiones y crea un borrador listo para revisar.',
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _load() async {
    try {
      final (sessions, warmups, categories) = await (
        widget.workouts.listGeneral(),
        widget.repository.warmups(),
        widget.repository.categories(),
      ).wait;
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _warmups = warmups;
          _categories = categories;
          _catalogsReady = true;
          _loading = false;
          _error = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudieron cargar las sesiones, calentamientos o categorías. Reintenta la carga.';
        });
      }
      return false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _checkpoint?.removeListener(_checkpointChanged);
    _checkpoint?.dispose();
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
      builder: (_) => GuidedSessionPicker(sessions: _sessions),
    );
    if (selected != null && mounted) {
      if (selected.status == 'published') {
        _attachSession(phase, selected);
      } else {
        await _reviewAndAttach(phase, selected.id);
      }
    }
  }

  void _attachSession(_PhaseFields phase, AdminWorkoutSummary session) {
    if (!_phases.contains(phase)) return;
    setState(() {
      phase.sessions.add(_SessionFields(session.id, session.name));
      phase.pendingSessions.remove(session.id);
      _changed();
    });
  }

  Future<void> _createSession(_PhaseFields phase) async {
    if (!await _saveWork() || !mounted) return;
    final id = await context.push<String>('/sessions/new?returnId=true');
    if (!mounted || id == null) return;
    setState(() {
      phase.pendingSessions.add(id);
      _changed();
    });
    if (!await _load() || !mounted) return;
    await _reviewAndAttach(phase, id);
  }

  Future<void> _reviewAndAttach(_PhaseFields phase, String id) async {
    var currentId = id;
    // Editar un borrador puede devolver otra versión; nunca se enlaza la anterior.
    while (mounted) {
      final session = _sessions.where((s) => s.id == currentId).firstOrNull;
      if (session == null) {
        setState(
          () => _error = 'La sesión pendiente ya no está disponible. Quita su referencia y elige otra del catálogo.',
        );
        return;
      }
      if (session.status == 'published') {
        _attachSession(phase, session);
        return;
      }
      if (session.status != 'draft') {
        setState(
          () => _error = 'La sesión pendiente está retirada. Quita su referencia y elige una publicada.',
        );
        return;
      }
      setState(() {
        phase.pendingSessions.add(currentId);
        _changed();
      });
      if (!await _saveWork() || !mounted) return;
      final reviewedId = await context.push<String>(
        '/sessions/${Uri.encodeComponent(currentId)}?returnId=true',
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (reviewedId != null) {
        setState(() {
          phase.pendingSessions.remove(currentId);
          phase.pendingSessions.add(reviewedId);
          _changed();
        });
      }
      if (!await _load() || !mounted) return;
      if (reviewedId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se ha añadido la sesión. Puedes retomar el borrador desde el programa o desde el catálogo.',
            ),
          ),
        );
        return;
      }
      currentId = reviewedId;
    }
  }

  Future<void> _createWarmup(_SessionFields session) async {
    if (!await _saveWork() || !mounted) return;
    final id = await context.push<String>('/warmups/new?returnId=true');
    if (!mounted || id == null) return;
    if (!await _load() || !mounted) return;
    if (_warmups.any((w) => w.id == id && w.status == 'published')) {
      setState(() {
        session.warmup = id;
        _changed();
      });
    }
  }

  Future<void> _reviewSession(_SessionFields session) async {
    await context.push('/sessions/${Uri.encodeComponent(session.id)}');
    if (mounted) await _load();
  }

  Future<void> _save() async {
    if (_busy || !_catalogsReady || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    try {
      if (_phases.any((p) => p.pendingSessions.isNotEmpty)) {
        throw const FormatException(
          'Tienes sesiones pendientes de incorporar. Retómalas o quita su referencia antes de guardar el programa; los borradores del catálogo se conservan.',
        );
      }
      final p = GuidedProgram(
        name: _name.text,
        description: _description.text,
        audience: _audience.text,
        equipment: _equipment.text,
        mode: _mode,
        phases: _phases.map((p) => p.input(_mode)).toList(),
        categories: _categories
            .where((c) => _categoryIds.contains(c.id))
            .toList(),
        primaryCategoryId: _primaryCategoryId,
      );
      validateGuidedProgram(p);
      for (final phase in _phases) {
        for (final session in phase.sessions) {
          final source = _sessions.where((s) => s.id == session.id).firstOrNull;
          if (!_sessions.any(
            (s) => s.id == session.id && s.status == 'published',
          )) {
            throw FormatException(
              '«${session.name}» ya no está publicada. Quita esa referencia y elige una sesión publicada.',
            );
          }
          if (session.warmup != null &&
              !_warmups.any(
                (w) => w.id == session.warmup && w.status == 'published',
              )) {
            throw FormatException(
              'Revisa el calentamiento de «${session.name}»: ya no está disponible.',
            );
          }
          if (session.warmup != null && source?.hasWarmup == true) {
            throw FormatException(
              '«${session.name}» ya incluye calentamiento. Quita el calentamiento adjunto.',
            );
          }
          if (session.adjustable && source?.supportsAdjustableRest != true) {
            throw FormatException(
              'El formato de «${session.name}» no admite ajustes genéricos de descanso. Desactiva esa opción.',
            );
          }
        }
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      if (!await _saveWork() || !mounted) return;
      if (_checkpoint == null) {
        await widget.repository.save(p, id: widget.original?.id);
      } else {
        _finalAttempt = p;
        await _checkpoint!.repository.finalize(_checkpoint!.work, p);
        _finalAttempt = null;
      }
      if (mounted) {
        setState(() => _dirty = false);
        context.canPop() ? context.pop(true) : context.go('/guided-programs');
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (e is PostgrestException &&
          ['22023', '23503', '42501'].contains(e.code)) {
        _finalAttempt = null;
      }
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
      onChanged: (_) => setState(_changed),
      validator: (v) =>
          required && (v ?? '').trim().isEmpty ? 'Completa este campo.' : null,
    ),
  );
  Future<void> _retryFinal() async {
    if (_busy || _finalAttempt == null) return;
    setState(() => _busy = true);
    try {
      await _checkpoint!.repository.finalize(_checkpoint!.work, _finalAttempt!);
      _finalAttempt = null;
      _dirty = false;
      if (mounted) {
        context.canPop() ? context.pop(true) : context.go('/guided-programs');
      }
    } catch (e) {
      if (e is PostgrestException &&
          ['22023', '23503', '42501'].contains(e.code)) {
        _finalAttempt = null;
      }
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar. Revisa la conexión y las sesiones publicadas.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _movePhase(int i, int delta) => setState(() {
    final p = _phases.removeAt(i);
    _phases.insert(i + delta, p);
    _changed();
  });
  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _checkpoint == null
        ? _dirty
        : _saveTimer?.isActive == true ||
              _checkpoint!.dirty ||
              _finalAttempt != null,
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
          : Stack(
              children: [
                AbsorbPointer(
                  absorbing: _busy || _finalAttempt != null,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Form(
                        key: _form,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            if (_checkpoint != null) _workStatus(),
                            _field(
                              _name,
                              'Nombre del programa',
                              required: true,
                            ),
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
                                  _changed();
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
                            _categoryFields(),
                            const SizedBox(height: 18),
                            for (var i = 0; i < _phases.length; i++)
                              _phaseCard(_phases[i], i),
                            if (_mode == GuidedProgramMode.phased)
                              OutlinedButton.icon(
                                onPressed: () => setState(() {
                                  _phases.add(_PhaseFields());
                                  _changed();
                                }),
                                icon: const Icon(Icons.add),
                                label: const Text('Añadir fase'),
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await context.push('/sessions');
                                    if (mounted) await _load();
                                  },
                                  child: const Text(
                                    'Publicar o revisar sesiones',
                                  ),
                                ),
                              ],
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (!_catalogsReady)
                              TextButton(
                                onPressed: _load,
                                child: const Text('Reintentar carga'),
                              ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _busy || !_catalogsReady
                                  ? null
                                  : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _busy
                                    ? 'Guardando…'
                                    : _checkpoint == null
                                    ? 'Guardar borrador'
                                    : 'Guardar en catálogo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_finalAttempt != null && !_busy)
                  Positioned.fill(
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'No se pudo confirmar el guardado en catálogo. Reintenta la misma operación; se conserva su identidad para evitar duplicados.',
                              ),
                              if (_error != null) Text(_error!),
                              FilledButton(
                                onPressed: _retryFinal,
                                child: const Text(
                                  'Comprobar y reintentar guardado',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
  Widget _categoryFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Categorías del programa',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 6),
      const Text(
        'Selecciona hasta ocho. La principal aparece en la tarjeta; todas participan en la búsqueda.',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final c in _categories.where(
            (c) => c.active || _categoryIds.contains(c.id),
          ))
            FilterChip(
              label: Text('${c.name}${c.active ? '' : ' (desactivada)'}'),
              selected: _categoryIds.contains(c.id),
              onSelected: (selected) => setState(() {
                if (selected) {
                  if (_categoryIds.length >= 8) {
                    _error = 'Puedes seleccionar hasta ocho categorías.';
                    return;
                  }
                  _categoryIds.add(c.id);
                  _primaryCategoryId ??= c.id;
                } else {
                  _categoryIds.remove(c.id);
                  if (_primaryCategoryId == c.id) {
                    _primaryCategoryId = _categoryIds.firstOrNull;
                  }
                }
                _changed();
              }),
            ),
        ],
      ),
      if (_categoryIds.isNotEmpty) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'primary-$_primaryCategoryId-${_categoryIds.join(',')}',
          ),
          initialValue: _primaryCategoryId,
          decoration: const InputDecoration(labelText: 'Categoría principal'),
          isExpanded: true,
          items: [
            for (final c in _categories.where(
              (c) => _categoryIds.contains(c.id),
            ))
              DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() {
            _primaryCategoryId = id;
            _changed();
          }),
        ),
      ],
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () async {
              final c = await editGuidedCategory(context, widget.repository);
              if (c != null && mounted) {
                setState(() {
                  _categories = [
                    ..._categories.where((old) => old.id != c.id),
                    c,
                  ];
                  if (_categoryIds.length < 8) {
                    _categoryIds.add(c.id);
                    _primaryCategoryId ??= c.id;
                  }
                  _changed();
                });
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear categoría'),
          ),
          TextButton(
            onPressed: () async {
              await manageGuidedCategories(context, widget.repository);
              if (mounted) await _load();
            },
            child: const Text('Gestionar categorías'),
          ),
        ],
      ),
    ],
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
                      _changed();
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
          Text(
            '${p.sessions.length} ${p.sessions.length == 1 ? 'sesión' : 'sesiones'} en ${_mode == GuidedProgramMode.guide ? 'esta rutina' : 'esta fase'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _createSession(p),
                icon: const Icon(Icons.add),
                label: const Text('Crear nueva sesión'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addSession(p),
                icon: const Icon(Icons.library_add_outlined),
                label: const Text('Elegir del catálogo'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Crea, revisa y publica para incorporar una sesión. El programa se guarda después con ${_checkpoint == null ? 'Guardar borrador' : 'Guardar en catálogo'}.',
            ),
          ),
          for (var i = 0; i < p.sessions.length; i++) _sessionCard(p, i),
          for (final id in p.pendingSessions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sessions.where((s) => s.id == id).firstOrNull?.name ??
                          'Sesión guardada en el catálogo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pendiente de incorporar al programa. El programa todavía no incluye esta sesión.',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () async {
                            if (await _load() && mounted) {
                              await _reviewAndAttach(p, id);
                            }
                          },
                          child: const Text('Retomar sesión'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            p.pendingSessions.remove(id);
                            _changed();
                          }),
                          child: const Text('Quitar referencia pendiente'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _sessionCard(_PhaseFields p, int i) {
    final s = p.sessions[i];
    final source = _sessions.where((item) => item.id == s.id).firstOrNull;
    final hasWarmup = source?.hasWarmup == true;
    final supportsRest = source?.supportsAdjustableRest == true;
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
                          _changed();
                        }),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar sesión',
                  onPressed: i == p.sessions.length - 1
                      ? null
                      : () => setState(() {
                          p.sessions.removeAt(i);
                          p.sessions.insert(i + 1, s);
                          _changed();
                        }),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Quitar sesión',
                  onPressed: () => setState(() {
                    p.sessions.removeAt(i).dispose();
                    _changed();
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _reviewSession(s),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Revisar sesión'),
              ),
            ),
            if (source == null || source.status != 'published')
              Text(
                'Esta versión ya no está publicada. Quita la referencia y elige otra sesión.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (hasWarmup)
              const Text('Esta sesión ya incluye su propio calentamiento.'),
            if (!hasWarmup)
              DropdownButtonFormField<String>(
                key: ValueKey('${s.id}:${s.warmup}'),
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
                  if (s.warmup != null &&
                      !_warmups.any((w) => w.id == s.warmup))
                    DropdownMenuItem(
                      value: s.warmup,
                      enabled: false,
                      child: const Text('Calentamiento no disponible'),
                    ),
                  for (final w in _warmups)
                    if (w.status == 'published' || w.id == s.warmup)
                      DropdownMenuItem(
                        value: w.id,
                        enabled: w.status == 'published',
                        child: Text(
                          '${w.name} · v${w.version}${w.status != 'published' ? ' · Retirado' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                // Una referencia retirada conserva su etiqueta hasta que el autor la cambie.
                onChanged: (v) {
                  setState(() {
                    s.warmup = v == '' ? null : v;
                    _changed();
                  });
                },
              ),
            if (!hasWarmup)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _createWarmup(s),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear y adjuntar calentamiento'),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir ajustar descansos entre series'),
              subtitle: const Text(
                'Solo bloques convencionales; se conservan los formatos temporizados.',
              ),
              value: s.adjustable,
              onChanged: !supportsRest && !s.adjustable
                  ? null
                  : (v) => setState(() {
                      s.adjustable = v;
                      _changed();
                    }),
            ),
            if (!supportsRest)
              const Text(
                'El formato de esta sesión no admite un ajuste genérico de descansos.',
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
  factory _SessionFields.restore(Map<String, dynamic> s) =>
      _SessionFields(
          s['id'] as String,
          s['name'] as String,
          warmup: s['warmup'] as String?,
        )
        ..adjustable = s['adjustable'] as bool
        ..minimum.text = s['minimum'] as String
        ..maximum.text = s['maximum'] as String;
  Map<String, dynamic> snapshot() => {
    'id': id,
    'name': name,
    'warmup': warmup,
    'adjustable': adjustable,
    'minimum': minimum.text,
    'maximum': maximum.text,
  };
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
  final pendingSessions = <String>{};
  factory _PhaseFields.restore(Map<String, dynamic> p) => _PhaseFields()
    ..name.text = p['name'] as String
    ..weeks.text = p['weeks'] as String
    ..instructions.text = p['instructions'] as String
    ..pendingSessions.addAll((p['pending'] as List).cast<String>())
    ..sessions.addAll(
      (p['sessions'] as List).map(
        (s) => _SessionFields.restore(Map<String, dynamic>.from(s as Map)),
      ),
    );
  Map<String, dynamic> snapshot() => {
    'name': name.text,
    'weeks': weeks.text,
    'instructions': instructions.text,
    'pending': pendingSessions.toList(),
    'sessions': sessions.map((s) => s.snapshot()).toList(),
  };
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
