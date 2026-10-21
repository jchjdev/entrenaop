import 'dart:async';

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

import 'guided_program_editor_adapter.dart';
import 'guided_program_work.dart';
import 'program_session_catalog.dart';
import 'program_session_picker.dart';
import 'workout_summary_line.dart';
import 'workout_template_content.dart';

class GuidedProgramEditorPage extends StatefulWidget {
  const GuidedProgramEditorPage({
    super.key,
    required this.repository,
    required this.workouts,
    required this.adapter,
    this.original,
    this.workRepository,
    this.work,
  });
  final GuidedProgramCompositionRepository repository;
  final ProgramSessionCatalog workouts;
  final GuidedProgramEditorAdapter adapter;
  final GuidedProgram? original;
  final GuidedWorkRepository? workRepository;
  final GuidedWork? work;
  @override
  State<GuidedProgramEditorPage> createState() =>
      _GuidedProgramEditorPageState();
}

class _GuidedProgramEditorPageState extends State<GuidedProgramEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _audience = TextEditingController(),
      _equipment = TextEditingController();
  GuidedProgramMode _mode = GuidedProgramMode.guide;
  final _phases = <_PhaseFields>[];
  final _removedSessions = <_SessionFields>{};
  List<ProgramSessionSummary> _sessions = [];
  final _sessionTemplates = <String, Future<WorkoutTemplate?>>{};
  List<GuidedWarmup> _warmups = [];
  List<GuidedProgramCategory> _categories = [];
  final _categoryIds = <String>{};
  String? _primaryCategoryId;
  bool _catalogsReady = false;
  bool _busy = false, _loading = true, _dirty = false;
  String? _savingVisibilityId;
  final _visibilityErrors = <String, String>{};
  String? _error;
  GuidedWorkController? _checkpoint;
  Timer? _saveTimer;
  GuidedProgram? _finalAttempt;
  bool _reviewAfterSave = false;
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
      _checkpoint =
          GuidedWorkController(
              widget.workRepository!,
              work,
              work.state.isEmpty ? _snapshot() : work.state,
            )
            ..update(_snapshot())
            ..addListener(_checkpointChanged);
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
    'phases': _phases
        .map((p) => p.snapshot(recovery: widget.adapter.recoverableSessions))
        .toList(),
  };
  void _restore(Map<String, dynamic> state) {
    if (state['schema'] != 1) {
      throw const FormatException(
        'Este borrador necesita otra versión del editor.',
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
        : 'Trabajo guardado · puedes continuar más tarde desde Programas';
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
                onPressed: () => widget.adapter.openPrograms(context),
                child: const Text('Abrir programas'),
              ),
            const Text(
              'Este guardado admite campos incompletos. El guardado final comprueba las sesiones y conserva el programa para revisarlo.',
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _load() async {
    try {
      final (loadedSessions, warmups, categories) = await (
        widget.workouts.listGeneral(),
        widget.repository.warmups(),
        widget.repository.categories(),
      ).wait;
      final sessions = [...loadedSessions];
      if (widget.adapter.professional) {
        // Una revisión de biblioteca no invalida otras posiciones del montaje
        // que siguen fijando esa receta, aunque se eligieran en esta pantalla.
        final known = sessions.map((s) => s.id).toSet();
        for (final id
            in _phases.expand((p) => p.sessions).map((s) => s.id).toSet()) {
          if (!known.add(id)) continue;
          final template = await widget.workouts.getTemplateById(id);
          if (template == null) continue;
          sessions.add(
            ProgramSessionSummary(
              id: id,
              name: template.name,
              status: 'published',
              version: template.version,
              isRunning: template.blocks.any(
                (b) => b.format == WorkoutBlockFormat.running,
              ),
              catalogScope: 'private',
              showInLibrary: false,
              supportsAdjustableRest: false,
            ),
          );
        }
      }
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
    for (final session in _removedSessions) {
      session.dispose();
    }
    super.dispose();
  }

  Future<void> _addSession(_PhaseFields phase) async {
    final selected = await showDialog<ProgramSessionSummary>(
      context: context,
      builder: (_) => ProgramSessionPicker(
        sessions: _sessions,
        statusBuilder: widget.adapter.sessionStatus,
        professional: widget.adapter.professional,
      ),
    );
    if (selected != null && mounted) {
      if (['draft', 'published'].contains(selected.status)) {
        _attachSession(phase, selected);
      } else {
        await _reviewAndAttach(phase, selected.id);
      }
    }
  }

  void _attachSession(_PhaseFields phase, ProgramSessionSummary session) {
    if (!_phases.contains(phase)) return;
    setState(() {
      phase.sessions.add(_SessionFields(session.id, session.name));
      phase.pendingSessions.remove(session.id);
      phase.pendingReplacements.remove(session.id);
      phase.replacementPositions.remove(session.id);
      _changed();
    });
  }

  bool _sessionWorkspaceOpen = false;

  Future<void> _createSession(_PhaseFields phase) => _openSession(phase);

  Future<void> _openSession(
    _PhaseFields phase, {
    _SessionFields? session,
    _SessionFields? duplicateOf,
  }) async {
    if (widget.adapter.recoverableSessions && _checkpoint != null) {
      await _openSessionWork(phase, session: session, duplicateOf: duplicateOf);
      return;
    }
    if (_sessionWorkspaceOpen || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sessionWorkspaceOpen = true);
    String? appliedId;
    try {
      if (!await _saveWork() || !mounted) return;
      await widget.adapter.openSession(
        context,
        programName: _name.text.trim().isEmpty
            ? 'Programa en borrador'
            : _name.text.trim(),
        sessionId: (session ?? duplicateOf)?.id,
        duplicate: duplicateOf != null,
        onSaved: (id) async {
          if (!mounted || !_phases.contains(phase)) {
            throw StateError('Programa cerrado');
          }
          // El enlace ya se aplicó en memoria. Confirmar la misma petición
          // incierta sin volver a guardar la sesión como pendiente de incorporar.
          if (appliedId == id) {
            if (!await _saveWork()) {
              throw StateError('Enlace pendiente de guardar');
            }
            return;
          }
          // Primero conservar el ID: si falla la lectura o el enlace se puede
          // recuperar sin crear otra sesión ni perder el trabajo del programa.
          setState(() {
            _sessionTemplates.remove(id);
            phase.pendingSessions.add(id);
            if (session != null) {
              phase.pendingReplacements[id] = session.id;
              phase.replacementPositions[id] = session.positionId;
            }
            _changed();
          });
          if (!await _saveWork()) throw StateError('Guardado pendiente');
          if (!await _load() || !mounted) {
            throw StateError('Catálogo no disponible');
          }
          final saved = _sessions.where((s) => s.id == id).firstOrNull;
          if (saved == null || !['draft', 'published'].contains(saved.status)) {
            throw StateError('Sesión no disponible');
          }
          if (session != null) {
            if (!phase.sessions.contains(session)) {
              throw StateError(
                'La posición original ya no está en el programa.',
              );
            }
            setState(() {
              session.id = id;
              session.name = saved.name;
              phase.pendingSessions.remove(id);
              phase.pendingReplacements.remove(id);
              phase.replacementPositions.remove(id);
              _changed();
            });
          } else if (appliedId != id) {
            _attachSession(phase, saved);
          }
          setState(() {
            phase.pendingSessions.remove(id);
            phase.pendingReplacements.remove(id);
            phase.replacementPositions.remove(id);
            _changed();
          });
          appliedId = id;
          if (!await _saveWork()) {
            throw StateError('Enlace pendiente de guardar');
          }
        },
      );
    } finally {
      if (mounted) {
        await _load();
        if (mounted) setState(() => _sessionWorkspaceOpen = false);
      }
    }
  }

  Future<void> _openSessionWork(
    _PhaseFields phase, {
    _SessionFields? session,
    _SessionFields? duplicateOf,
    String? workId,
  }) async {
    if (_sessionWorkspaceOpen || _busy) return;
    setState(() => _sessionWorkspaceOpen = true);
    try {
      final existing = session == null
          ? null
          : phase.sessionWorks.entries
                .where((e) => e.value['positionId'] == session.positionId)
                .firstOrNull;
      final id = workId ?? existing?.key ?? newGuidedWorkId();
      final origin = phase.sessionWorks.putIfAbsent(
        id,
        () => {
          'baseId': (session ?? duplicateOf)?.id,
          'programId': null,
          'parentWorkId': _checkpoint!.work.id,
          'phaseId': phase.phaseId,
          'positionId': session?.positionId ?? newGuidedWorkId(),
          'duplicate': duplicateOf != null,
        },
      );
      if (!await _saveWork() || !mounted) return;
      await widget.adapter.openSessionWork(
        context,
        workId: id,
        origin: origin,
        programName: _name.text.trim().isEmpty
            ? 'Programa en borrador'
            : _name.text.trim(),
        onSaved: (resultId) async {
          if (!mounted || !_phases.contains(phase)) {
            throw StateError('Destino no disponible');
          }
          final slot = phase.sessions
              .where((s) => s.positionId == origin['positionId'])
              .firstOrNull;
          if (slot?.id == resultId && !phase.sessionWorks.containsKey(id)) {
            if (!await _saveWork()) throw StateError('Enlace pendiente');
            return;
          }
          if (!await _load() || !mounted) {
            throw StateError('Catálogo pendiente');
          }
          final saved = _sessions.where((s) => s.id == resultId).firstOrNull;
          if (saved == null) throw StateError('Sesión no disponible');
          final replacing =
              origin['baseId'] != null && origin['duplicate'] != true;
          if (replacing && (slot == null || slot.id != origin['baseId'])) {
            throw StateError(
              'La posición original ha cambiado. Se conserva la sesión guardada.',
            );
          }
          setState(() {
            if (slot != null) {
              slot.id = resultId;
              slot.name = saved.name;
            } else {
              phase.sessions.add(
                _SessionFields(
                  resultId,
                  saved.name,
                  positionId: origin['positionId'] as String,
                ),
              );
            }
            phase.sessionWorks.remove(id);
            _sessionTemplates.remove(resultId);
            _changed();
          });
          if (!await _saveWork()) throw StateError('Enlace pendiente');
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo confirmar la sesión o su enlace. El trabajo se conserva para retomarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _sessionWorkspaceOpen = false);
    }
  }

  Future<void> _discardSessionWork(_PhaseFields phase, String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar este trabajo incompleto?'),
        content: const Text(
          'Las sesiones guardadas y las utilizadas en otros programas se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar trabajando'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar trabajo'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.adapter.discardSessionWork(id);
      if (!mounted) return;
      setState(() => phase.sessionWorks.remove(id));
      if (!await _saveWork()) throw StateError('Referencia pendiente');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo descartar. Si la sesión ya está guardada, retómala para confirmar su enlace.',
        );
      }
    }
  }

  Future<void> _reviewAndAttach(_PhaseFields phase, String id) async {
    final source = _sessions.where((s) => s.id == id).firstOrNull;
    if (source != null && ['draft', 'published'].contains(source.status)) {
      final positionId = phase.replacementPositions[id];
      final previousId = phase.pendingReplacements[id];
      final replacing = positionId != null || previousId != null;
      if (!replacing) {
        _attachSession(phase, source);
      } else {
        final candidates = phase.sessions
            .where(
              (session) => positionId != null
                  ? session.positionId == positionId
                  : session.id == previousId,
            )
            .toList();
        // Un ID de receta puede ocupar varias posiciones. Nunca se elige la
        // primera por casualidad ni se convierte una sustitución en un añadido.
        final previous =
            candidates.length == 1 &&
                (candidates.single.id == previousId ||
                    candidates.single.id == id)
            ? candidates.single
            : await _chooseReplacementPosition(phase);
        if (previous == null || !mounted) return;
        if (!_phases.contains(phase) || !phase.sessions.contains(previous)) {
          setState(
            () => _error = 'La posición elegida ya no está en el programa. La revisión sigue pendiente.',
          );
          return;
        }
        setState(() {
          previous.id = source.id;
          previous.name = source.name;
          phase.pendingSessions.remove(id);
          phase.pendingReplacements.remove(id);
          phase.replacementPositions.remove(id);
          _changed();
        });
      }
      await _saveWork();
    } else {
      setState(
        () => _error =
            'La sesión pendiente no está disponible. Elige otra del catálogo.',
      );
    }
  }

  Future<_SessionFields?> _chooseReplacementPosition(_PhaseFields phase) async {
    if (phase.sessions.isEmpty) {
      setState(
        () => _error = 'La posición original ya no está en el programa. La revisión sigue pendiente; puedes elegirla después desde el catálogo.',
      );
      return null;
    }
    return showDialog<_SessionFields>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Elige la posición que quieres sustituir'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'La posición original ya no puede recuperarse automáticamente. Elige dónde aplicar esta revisión guardada. No se añadirá otra sesión.',
            ),
          ),
          for (var index = 0; index < phase.sessions.length; index++)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(phase.sessions[index]),
              child: Text('${index + 1}. ${phase.sessions[index].name}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createWarmup(_SessionFields session) async {
    if (!await _saveWork() || !mounted) return;
    final id = await widget.adapter.createWarmup(context);
    if (!mounted || id == null) return;
    if (!await _load() || !mounted) return;
    if (_warmups.any((w) => w.id == id && w.status == 'published')) {
      setState(() {
        session.warmup = id;
        _changed();
      });
    }
  }

  Future<void> _editSession(_SessionFields session) async {
    final phase = _phases
        .where((p) => p.sessions.contains(session))
        .firstOrNull;
    if (phase != null) await _openSession(phase, session: session);
  }

  Future<void> _setSessionVisibility(
    ProgramSessionSummary source,
    bool value,
  ) async {
    if (_busy ||
        source.catalogScope != 'general' ||
        source.status != 'published' ||
        value == source.showInLibrary) {
      return;
    }
    setState(() {
      _busy = true;
      _savingVisibilityId = source.id;
      _visibilityErrors.remove(source.id);
    });
    try {
      await widget.workouts.setLibraryVisibility(
        source.id,
        value,
        expected: source.showInLibrary,
      );
      if (mounted) {
        setState(() {
          // La marca pertenece a la sesión compartida, no a una fase concreta.
          _sessions = [
            for (final session in _sessions)
              if (session.id == source.id)
                session.withLibraryVisibility(value)
              else
                session,
          ];
        });
      }
    } catch (error) {
      // Una pestaña pudo cambiar la marca; recargar permite reintentar con el
      // valor esperado vigente sin sobrescribirlo silenciosamente.
      final message = widget.adapter.visibilityError(error);
      if (message != null) await _load();
      if (mounted) {
        setState(() {
          _visibilityErrors[source.id] = message ?? 'No se pudo guardar la visibilidad. Vuelve a usar el interruptor para reintentar.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _savingVisibilityId = null;
        });
      }
    }
  }

  Future<void> _save({bool reviewAfter = false}) async {
    if (_busy || !_catalogsReady || !_form.currentState!.validate()) return;
    _reviewAfterSave = reviewAfter;
    FocusScope.of(context).unfocus();
    try {
      if (_phases.any(
        (p) => p.pendingSessions.isNotEmpty || p.sessionWorks.isNotEmpty,
      )) {
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
            (s) =>
                s.id == session.id && ['draft', 'published'].contains(s.status),
          )) {
            throw FormatException(
              '«${session.name}» ya no está disponible. Quita esa referencia y elige otra sesión.',
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
      final String savedId;
      if (_checkpoint == null) {
        if (widget.adapter.professional) _finalAttempt = p;
        savedId = await widget.repository.save(p, id: widget.original?.id);
        _finalAttempt = null;
      } else {
        _finalAttempt = p;
        savedId = await _checkpoint!.repository.finalize(_checkpoint!.work, p);
        _finalAttempt = null;
      }
      if (mounted) _finishSave(savedId);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (widget.adapter.definitiveError(e)) {
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

  void _finishSave(String id) {
    setState(() {
      _dirty = false;
      _busy = false;
    });
    widget.adapter.finish(context, id, _reviewAfterSave);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    bool required = false,
    bool numeric = false,
  }) => _labeledControl(
    label,
    TextFormField(
      key: ValueKey('program-field-$label'),
      controller: c,
      maxLines: lines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: const InputDecoration(),
      onChanged: (_) => setState(_changed),
      validator: (v) =>
          required && (v ?? '').trim().isEmpty ? 'Completa este campo.' : null,
    ),
  );

  // La etiqueta ocupa espacio real y puede envolver líneas sin invadir el
  // control anterior; se conserva su nombre accesible en el campo.
  Widget _labeledControl(String label, Widget control) => Padding(
    key: ValueKey('program-label-$label'),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: control),
      ],
    ),
  );

  Widget _header(Widget title, List<Widget> actions) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 400 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(children: actions),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          ...actions,
        ],
      );
    },
  );

  Widget _sessionSwitch({
    required String title,
    required Widget subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => LayoutBuilder(
    key: ValueKey('program-switch-$title'),
    builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title),
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: subtitle,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: title,
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ),
            ],
          ),
        );
      }
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      );
    },
  );
  Future<void> _retryFinal() async {
    if (_busy || _finalAttempt == null) return;
    setState(() => _busy = true);
    try {
      final savedId = _checkpoint == null
          ? await widget.repository.save(
              _finalAttempt!,
              id: widget.original?.id,
            )
          : await _checkpoint!.repository.finalize(
              _checkpoint!.work,
              _finalAttempt!,
            );
      _finalAttempt = null;
      if (mounted) _finishSave(savedId);
    } catch (e) {
      if (widget.adapter.definitiveError(e)) {
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
    isBusy: () => _busy || _sessionWorkspaceOpen,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.original == null
              ? widget.adapter.professional
                    ? 'Crear programa privado'
                    : 'Crear programa guiado'
              : widget.adapter.professional
              ? 'Revisar programa privado'
              : 'Editar programa guiado',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                AbsorbPointer(
                  absorbing:
                      _busy || _sessionWorkspaceOpen || _finalAttempt != null,
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
                                  ? widget.adapter.professional
                                        ? 'Elige las fechas al pautar las sesiones a cada alumno.'
                                        : 'Las sesiones se pueden repetir sin fecha de finalización.'
                                  : widget.adapter.professional
                                  ? 'Las fases organizan el trabajo. Tú eliges qué sesiones pautar y en qué fechas.'
                                  : 'El usuario confirma el paso de fase; el calendario no lo hace avanzar.',
                            ),
                            const SizedBox(height: 18),
                            if (!widget.adapter.professional) _categoryFields(),
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
                                    await widget.adapter.openLibrary(context);
                                    if (mounted) {
                                      _sessionTemplates.clear();
                                      await _load();
                                    }
                                  },
                                  child: Text(
                                    widget.adapter.professional
                                        ? 'Abrir mis sesiones privadas'
                                        : 'Ver catálogo de sesiones',
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
                            if (!widget.adapter.professional)
                              OutlinedButton.icon(
                                onPressed: _busy || !_catalogsReady
                                    ? null
                                    : () => _save(reviewAfter: true),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('Guardar y revisar'),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy || !_catalogsReady
                                  ? null
                                  : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _busy
                                    ? 'Guardando…'
                                    : widget.adapter.professional
                                    ? 'Guardar programa privado'
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
                        child: SingleChildScrollView(
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
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final c in _categories.where(
              (c) => c.active || _categoryIds.contains(c.id),
            ))
              FilterChip(
                label: ConstrainedBox(
                  // Reservar sitio al check y rellenos antes de medir el texto
                  // permite que el chip calcule su altura con todas las líneas.
                  constraints: BoxConstraints(
                    maxWidth: (constraints.maxWidth - 80).clamp(
                      1,
                      double.infinity,
                    ),
                  ),
                  child: Builder(
                    builder: (context) => DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style,
                      child: Text(
                        '${c.name}${c.active ? '' : ' (desactivada)'}',
                        softWrap: true,
                      ),
                    ),
                  ),
                ),
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
      ),
      if (_categoryIds.isNotEmpty) ...[
        _labeledControl(
          'Categoría principal',
          DropdownButtonFormField<String>(
            key: ValueKey(
              'primary-$_primaryCategoryId-${_categoryIds.join(',')}',
            ),
            initialValue: _primaryCategoryId,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            isExpanded: true,
            isDense: false,
            itemHeight: null,
            items: [
              for (final c in _categories.where(
                (c) => _categoryIds.contains(c.id),
              ))
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, softWrap: true),
                ),
            ],
            onChanged: (id) => setState(() {
              _primaryCategoryId = id;
              _changed();
            }),
          ),
        ),
      ],
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () async {
              final c = await widget.adapter.createCategory(context);
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
              await widget.adapter.manageCategories(context);
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
            _header(
              Text(
                'Fase ${index + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              [
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
                    onPressed: p.sessionWorks.isNotEmpty
                        ? null
                        : () => setState(() {
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
              widget.adapter.professional
                  ? 'Las sesiones se guardan en tu biblioteca privada. Guardar el programa no lo asigna a ningún alumno.'
                  : 'Crea y guarda las sesiones aquí. Se publicarán juntas tras revisar el programa. Guarda tu montaje con ${_checkpoint == null ? 'Guardar borrador' : 'Guardar en catálogo'}.',
            ),
          ),
          for (var i = 0; i < p.sessions.length; i++) _sessionCard(p, i),
          for (final entry in p.sessionWorks.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sesión incompleta o pendiente de enlazar'),
                    const Text(
                      'Retoma los campos guardados sin crear otra sesión.',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () =>
                              _openSessionWork(p, workId: entry.key),
                          child: const Text('Retomar sesión'),
                        ),
                        TextButton(
                          onPressed: () => _discardSessionWork(p, entry.key),
                          child: const Text('Descartar trabajo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                            p.pendingReplacements.remove(id);
                            p.replacementPositions.remove(id);
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
  void _removeSession(_PhaseFields phase, int index) {
    final session = phase.sessions[index];
    setState(() {
      phase.sessions.removeAt(index);
      // Se conserva la misma referencia y sus controles hasta deshacer o salir.
      _removedSessions.add(session);
      _changed();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Se ha quitado «${session.name}» del programa.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (!mounted ||
                !_phases.contains(phase) ||
                !_removedSessions.contains(session)) {
              return;
            }
            setState(() {
              _removedSessions.remove(session);
              phase.sessions.insert(
                index.clamp(0, phase.sessions.length),
                session,
              );
              _changed();
            });
          },
        ),
      ),
    );
  }

  Widget _sessionCard(_PhaseFields p, int i) {
    final s = p.sessions[i];
    final pendingWork = p.sessionWorks.values.any(
      (origin) => origin['positionId'] == s.positionId,
    );
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
            _header(
              Text(
                '${i + 1}. ${s.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              [
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
                  onPressed: pendingWork ? null : () => _removeSession(p, i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    '${widget.adapter.professional && source != null ? 'Privada' : switch (source?.status) {
                            'draft' => 'Borrador',
                            'published' => 'Publicada',
                            'archived' => 'Retirada',
                            _ => 'No disponible',
                          }}${source == null ? '' : ' · v${source.version}'}',
                  ),
                ),
              ],
            ),
            widget.adapter.sessionStatus(source),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      source != null &&
                          ['draft', 'published'].contains(source.status)
                      ? () => _editSession(s)
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar sesión'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      source != null &&
                          ['draft', 'published'].contains(source.status)
                      ? () => _openSession(p, duplicateOf: s)
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicar sesión'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    s.contentExpanded = !s.contentExpanded;
                  }),
                  icon: Icon(
                    s.contentExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(
                    s.contentExpanded ? 'Ocultar contenido' : 'Ver contenido',
                  ),
                ),
              ],
            ),
            if (source == null ||
                !['draft', 'published'].contains(source.status))
              Text(
                'Esta versión no está disponible. Quita la referencia y elige otra sesión.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              _sessionContent(s.id, collapsed: !s.contentExpanded),
            if (!widget.adapter.professional)
              ExpansionTile(
                initiallyExpanded: s.settingsExpanded,
                onExpansionChanged: (expanded) =>
                    setState(() => s.settingsExpanded = expanded),
                tilePadding: EdgeInsets.zero,
                title: const Text('Calentamiento y ajustes'),
                subtitle: Text(
                  [
                    if (hasWarmup)
                      'Calentamiento incluido'
                    else if (s.warmup != null)
                      _warmups
                              .where((w) => w.id == s.warmup)
                              .firstOrNull
                              ?.name ??
                          'Calentamiento no disponible'
                    else
                      'Sin calentamiento adjunto',
                    if (s.adjustable) 'Descansos ajustables',
                  ].join(' · '),
                ),
                children: [
                  if (source?.catalogScope == 'general' &&
                      source?.status == 'published')
                    _sessionSwitch(
                      title: 'Mostrar en Sesiones de EntrenaOP',
                      subtitle: _savingVisibilityId == source!.id
                          ? const Text('Guardando visibilidad…')
                          : const Text(
                              'Cambia la visibilidad de esta sesión en todos sus programas.',
                            ),
                      value: source.showInLibrary,
                      onChanged: _busy
                          ? null
                          : (value) => _setSessionVisibility(source, value),
                    ),
                  if (_visibilityErrors[s.id] case final message?)
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (hasWarmup)
                    const Text(
                      'Esta sesión ya incluye su propio calentamiento.',
                    ),
                  if (!hasWarmup)
                    _labeledControl(
                      'Calentamiento adjunto',
                      DropdownButtonFormField<String>(
                        key: ValueKey('${s.id}:${s.warmup}'),
                        initialValue: s.warmup ?? '',
                        isExpanded: true,
                        isDense: false,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(
                              'Sin calentamiento adjunto',
                              softWrap: true,
                            ),
                          ),
                          if (s.warmup != null &&
                              !_warmups.any((w) => w.id == s.warmup))
                            DropdownMenuItem(
                              value: s.warmup,
                              enabled: false,
                              child: const Text(
                                'Calentamiento no disponible',
                                softWrap: true,
                              ),
                            ),
                          for (final w in _warmups)
                            if (w.status == 'published' || w.id == s.warmup)
                              DropdownMenuItem(
                                value: w.id,
                                enabled: w.status == 'published',
                                child: Text(
                                  '${w.name} · v${w.version}${w.status != 'published' ? ' · Retirado' : ''}',
                                  softWrap: true,
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
                  _sessionSwitch(
                    title: 'Permitir ajustar descansos entre series',
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
          ],
        ),
      ),
    );
  }

  Widget _sessionContent(String id, {bool collapsed = false}) =>
      FutureBuilder<WorkoutTemplate?>(
        key: ValueKey('program-session-content-$id'),
        // Una misma receta se lee una sola vez aunque figure en varias fases.
        // Guardar desde la ventana invalida solo la receta modificada.
        future: _sessionTemplates.putIfAbsent(
          id,
          () async => widget.workouts.getTemplateById(id),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Cargando sesión…'),
            );
          }
          final template = snapshot.data;
          if (snapshot.hasError || template == null) {
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _sessionTemplates.remove(id);
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('No se pudo cargar el contenido. Reintentar'),
              ),
            );
          }
          return collapsed
              ? WorkoutSummaryLine(template: template)
              : WorkoutTemplateContent(template: template, showTitle: false);
        },
      );
}

class _SessionFields {
  _SessionFields(this.id, this.name, {this.warmup, String? positionId})
    : positionId = positionId ?? newGuidedWorkId();
  factory _SessionFields.fromSession(GuidedSession s) =>
      _SessionFields(s.templateId, s.name, warmup: s.warmupId)
        ..adjustable = s.restPolicy.adjustable
        ..minimum.text = '${s.restPolicy.minimumSeconds ?? 60}'
        ..maximum.text = '${s.restPolicy.maximumSeconds ?? 180}';
  String id, name;
  final String positionId;
  factory _SessionFields.restore(Map<String, dynamic> s) =>
      _SessionFields(
          s['id'] as String,
          s['name'] as String,
          warmup: s['warmup'] as String?,
          positionId: s['positionId'] as String?,
        )
        ..adjustable = s['adjustable'] as bool
        ..minimum.text = s['minimum'] as String
        ..maximum.text = s['maximum'] as String;
  Map<String, dynamic> snapshot() => {
    'id': id,
    'positionId': positionId,
    'name': name,
    'warmup': warmup,
    'adjustable': adjustable,
    'minimum': minimum.text,
    'maximum': maximum.text,
  };
  String? warmup;
  bool contentExpanded = true;
  bool settingsExpanded = false;
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
  _PhaseFields({String? phaseId}) : phaseId = phaseId ?? newGuidedWorkId();
  final String phaseId;
  final sessionWorks = <String, Map<String, dynamic>>{};
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
  // Si se interrumpe el enlace de una revisión, recuperar debe reemplazar su
  // posición original, no añadir otra sesión al final del programa.
  final pendingReplacements = <String, String>{};
  final replacementPositions = <String, String>{};
  factory _PhaseFields.restore(Map<String, dynamic> p) =>
      _PhaseFields(phaseId: p['phaseId'] as String?)
        ..sessionWorks.addAll({
          for (final e in (p['sessionWorks'] as Map? ?? {}).entries)
            e.key as String: Map<String, dynamic>.from(e.value as Map),
        })
        ..name.text = p['name'] as String
        ..weeks.text = p['weeks'] as String
        ..instructions.text = p['instructions'] as String
        ..pendingSessions.addAll((p['pending'] as List).cast<String>())
        ..pendingReplacements.addAll(
          (p['replacements'] as Map?)?.cast<String, String>() ?? const {},
        )
        ..replacementPositions.addAll(
          (p['replacementPositions'] as Map?)?.cast<String, String>() ??
              const {},
        )
        ..sessions.addAll(
          (p['sessions'] as List).map(
            (s) => _SessionFields.restore(Map<String, dynamic>.from(s as Map)),
          ),
        );
  Map<String, dynamic> snapshot({bool recovery = false}) => {
    if (recovery) 'phaseId': phaseId,
    if (recovery) 'sessionWorks': sessionWorks,
    'name': name.text,
    'weeks': weeks.text,
    'instructions': instructions.text,
    'pending': pendingSessions.toList(),
    'replacements': Map<String, String>.of(pendingReplacements),
    'replacementPositions': Map<String, String>.of(replacementPositions),
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
