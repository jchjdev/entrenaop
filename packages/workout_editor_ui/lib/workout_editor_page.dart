import 'package:workout_editor_ui/duration_input_formatter.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:async';

import 'workout_editor_work.dart';
import 'editor_work_checkpoint.dart';
import 'running_editor_actions.dart';
import 'running_editor_groups.dart';
import 'running_step_card.dart';
import 'running_reorderable_steps.dart';

import 'package:workout_core/workout_draft_codec.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/running_workout_estimator.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/running_step_fields.dart';
import 'package:workout_editor_ui/workout_format_field.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/compact_field_layout.dart';

import 'workout_editor_exercise.dart';
import 'exercise_preferences_controller.dart';

/// Creador común: edita la receta; el consumidor aporta catálogo, guardado y salida.
/// La visibilidad y los permisos pertenecen a la aplicación y al servidor.
class WorkoutEditorPage extends StatefulWidget {
  const WorkoutEditorPage({
    super.key,
    required this.loadExercises,
    required this.onSave,
    required this.onSaved,
    required this.title,
    required this.heading,
    required this.instructions,
    required this.saveLabel,
    this.wideTitle,
    this.originalTemplate,
    this.warmup = false,
    this.additionalFields,
    this.additionalStateStamp = '',
    this.emptyCatalogMessage = 'No hay ejercicios disponibles.',
    this.saveErrorMessage =
        'No se pudo guardar el borrador. Revisa permisos y conexión.',
    this.embedded = false,
    this.onCreateExercise,
    this.exercisePreferences,
    this.workBinding,
    this.initialEditorState,
    this.fixedRunningMode,
    this.saveLocalDraft,
    this.onClose,
  });

  final Future<List<WorkoutEditorExercise>> Function() loadExercises;

  /// El consumidor crea en su catálogo autorizado y devuelve la identidad guardada.
  final Future<WorkoutEditorExercise?> Function(BuildContext)? onCreateExercise;
  final ExerciseCatalogPreferences? exercisePreferences;
  final WorkoutEditorWorkBinding? workBinding;
  final Map<String, dynamic>? initialEditorState;

  /// El acceso de carrera/fuerza del deportista conserva su modalidad.
  final bool? fixedRunningMode;

  /// Persistencia local aportada por el consumidor, sin SDK ni cuentas aquí.
  final Future<void> Function(Map<String, dynamic>)? saveLocalDraft;
  final VoidCallback? onClose;
  final Future<String> Function(CreatePersonalWorkoutInput) onSave;
  final ValueChanged<String> onSaved;
  final String title, heading, instructions, saveLabel;
  final String? wideTitle;
  final WorkoutTemplate? originalTemplate;
  final bool warmup;
  final bool embedded;

  /// Campos del contexto de autoría, sin trasladar su semántica al creador.
  final Widget? additionalFields;

  /// Firma del estado adicional para proteger también esos cambios al salir.
  final String additionalStateStamp;
  final String emptyCatalogMessage, saveErrorMessage;

  @override
  State<WorkoutEditorPage> createState() => _WorkoutEditorPageState();
}

class _WorkoutEditorPageState extends State<WorkoutEditorPage>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _segments = <_Segment>[_Segment()];
  _Segment? _expandedSegment;
  _Segment? _invalidSegment;
  final _separateRepetitions = <_Segment>{};
  final _groupBreaks = <_Segment>{};
  final _blocks = <_StrengthBlock>[_StrengthBlock()];
  List<WorkoutEditorExercise> _catalog = const [];
  bool _running = true;
  bool _busy = false;
  bool _creatingExercise = false;
  ExercisePreferencesController? _exercisePreferences;
  String? _error;
  WorkoutEditorWorkController? _work;
  Timer? _workTimer;
  String? _observedWork;
  String? _workLoadError;
  bool _canReopen = false;
  final _observedControllers = <TextEditingController>{};
  Future<void>? _localWrite;
  bool _localFinalized = false;

  Map<String, dynamic> _rawSnapshot() => {
    'schema': 1,
    'nameText': _name.text,
    'descriptionText': _description.text,
    'durationText': _duration.text,
    'running': _running,
    'segments': [for (final v in _segments) v.raw],
    'blocks': [
      for (final b in _blocks)
        {
          'nameText': b.name.text,
          'format': b.format.name,
          'roundsText': b.rounds.text,
          'restText': b.rest.text,
          'capText': b.cap.text,
          'exercises': [
            for (final e in b.exercises)
              {
                'exerciseId': e.exerciseId,
                'targetType': e.type.name,
                'automaticSlot': e.automaticSlot,
                'customSets': e.customSets,
                'countText': e.count.text,
                'targetText': e.target.text,
                'restText': e.rest.text,
                'loadText': e.load.text,
                'rirText': e.rir.text,
                'amrapRepetitionsText': e.amrapRepetitions.text,
                'amrapRirText': e.amrapRir.text,
                'variations': [
                  for (final v in e.variations.entries)
                    if (v.value.hasValues)
                      {
                        'setIndex': v.key,
                        'targetText': v.value.target.text,
                        'restText': v.value.rest.text,
                        'loadText': v.value.load.text,
                        'rirText': v.value.rir.text,
                      },
                ],
              },
          ],
        },
    ],
  };

  Map<String, dynamic> _workState({Map<String, dynamic>? intent}) => {
    'schema': 1,
    'editor': _rawSnapshot(),
    'context': widget.workBinding!.captureContext(),
    'intent': ?intent,
  };

  void _restoreRaw(Map<String, dynamic> raw) {
    WorkoutEditorSnapshot(raw);
    _name.text = raw['nameText'] as String;
    _description.text = raw['descriptionText'] as String;
    _duration.text = raw['durationText'] as String;
    _running = raw['running'] as bool;
    for (final v in _segments) {
      v.dispose();
    }
    _segments.clear();
    for (final row in raw['segments'] as List) {
      _segments.add(_Segment.fromRaw(row as Map));
    }
    for (final v in _blocks) {
      v.dispose();
    }
    _blocks.clear();
    for (final row in raw['blocks'] as List) {
      final b = _StrengthBlock()
        ..name.text = row['nameText'] as String
        ..format = WorkoutBlockFormat.values.byName(row['format'] as String)
        ..rounds.text = row['roundsText'] as String
        ..rest.text = row['restText'] as String
        ..cap.text = row['capText'] as String;
      b.exercises.single.dispose();
      b.exercises.clear();
      for (final r in row['exercises'] as List) {
        final e = _Exercise(automaticSlot: r['automaticSlot'] as bool)
          ..exerciseId = r['exerciseId'] as String?
          ..type = WorkoutTargetType.values.byName(r['targetType'] as String)
          ..customSets = r['customSets'] as bool
          ..count.text = r['countText'] as String
          ..target.text = r['targetText'] as String
          ..rest.text = r['restText'] as String
          ..load.text = r['loadText'] as String
          ..rir.text = r['rirText'] as String
          ..amrapRepetitions.text = r['amrapRepetitionsText'] as String
          ..amrapRir.text = r['amrapRirText'] as String;
        for (final v in r['variations'] as List) {
          e.variations[v['setIndex'] as int] = _SetVariation()
            ..target.text = v['targetText'] as String
            ..rest.text = v['restText'] as String
            ..load.text = v['loadText'] as String
            ..rir.text = v['rirText'] as String;
        }
        b.exercises.add(e);
      }
      _blocks.add(b);
    }
  }

  void _workChanged() {
    if (mounted) setState(() {});
  }

  void _observeWork() {
    if ((_work == null && widget.saveLocalDraft == null) ||
        _workLoadError != null ||
        _work?.finalizing == true ||
        _localFinalized) {
      return;
    }
    final fields = [
      _name,
      _description,
      _duration,
      for (final s in _segments) ...[
        s.count,
        s.target,
        s.pace,
        s.paceMax,
        s.recoveryTime,
      ],
      for (final b in _blocks) ...[
        b.name,
        b.rounds,
        b.rest,
        b.cap,
        for (final e in b.exercises) ...[
          e.count,
          e.target,
          e.rest,
          e.load,
          e.rir,
          e.amrapRepetitions,
          e.amrapRir,
          for (final v in e.variations.values) ...[
            v.target,
            v.rest,
            v.load,
            v.rir,
          ],
        ],
      ],
    ];
    for (final field in fields) {
      if (_observedControllers.add(field)) field.addListener(_queueWork);
    }
    _queueWork();
  }

  void _queueWork() {
    if ((_work == null && widget.saveLocalDraft == null) ||
        _work?.finalizing == true ||
        _workLoadError != null ||
        _localFinalized ||
        _busy) {
      return;
    }
    if (_work == null) {
      final stamp = canonicalEditorState(_rawSnapshot());
      if (stamp == _observedWork) return;
      _observedWork = stamp;
      _workTimer?.cancel();
      _workTimer = Timer(const Duration(milliseconds: 700), _saveWork);
      return;
    }
    final state = _workState();
    final stamp = canonicalEditorState(state);
    if (stamp == _observedWork) return;
    _observedWork = stamp;
    _work!.update(state);
    _workTimer?.cancel();
    _workTimer = Timer(const Duration(milliseconds: 700), () async {
      await _saveWork();
    });
  }

  Future<bool> _saveWork() async {
    _workTimer?.cancel();
    if (_work == null) {
      if (_localFinalized || widget.saveLocalDraft == null) return true;
      final snapshot = _rawSnapshot();
      final previous = _localWrite;
      // Serializar también las escrituras locales: una antigua no puede
      // terminar después del borrado que sigue a guardar la sesión.
      final write = () async {
        try {
          await previous;
        } catch (_) {
          /* Permitir recuperar un fallo previo. */
        }
        await widget.saveLocalDraft!(snapshot);
      }();
      _localWrite = write;
      try {
        await write;
        return true;
      } catch (_) {
        return false;
      }
    }
    final work = _work!;
    if (!work.finalizing) work.update(_workState());
    try {
      await work.flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _saveBeforeExit() async {
    if (_workLoadError != null) return true;
    if (!await _saveWork()) throw StateError('Trabajo pendiente');
    return true;
  }

  Widget _workStatus() {
    final work = _work!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          work.finalizing
              ? 'Guardado final pendiente de confirmar. Tus datos se conservan.'
              : work.conflict
              ? 'Otra pestaña ha cambiado este trabajo. Conserva esta pantalla y abre la versión actual.'
              : work.error != null
              ? 'No se ha guardado el último cambio. Reintenta antes de cerrar.'
              : work.saving
              ? 'Guardando trabajo…'
              : work.dirty
              ? 'Cambios pendientes de guardar'
              : work.work.revision == 0
              ? 'El trabajo se guarda al empezar a editar'
              : 'Trabajo guardado · puedes retomarlo más tarde',
        ),
        if (!work.conflict)
          TextButton.icon(
            onPressed: _busy
                ? null
                : work.finalizing
                ? _save
                : _saveWork,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              work.finalizing ? 'Confirmar guardado' : 'Guardar trabajo ahora',
            ),
          ),
        if (_canReopen)
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await _work!.reopen();
                      if (mounted) {
                        setState(() {
                          _canReopen = false;
                          _error = null;
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error = 'No se pudo volver a editar. Confirma primero el estado del guardado.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Volver a editar el trabajo'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  late String _savedStamp;
  String get _draftStamp => jsonEncode([
    _name.text,
    _description.text,
    _duration.text,
    _running,
    widget.additionalStateStamp,
    for (final segment in _segments)
      [
        segment.count.text,
        segment.target.text,
        segment.pace.text,
        segment.paceMax.text,
        segment.recoveryTime.text,
        segment.byDistance,
        segment.kind?.name,
        segment.manual,
        segment.recoveryByDistance,
        segment.recovery?.name,
      ],
    for (final block in _blocks)
      [
        block.name.text,
        block.rounds.text,
        block.rest.text,
        block.cap.text,
        block.format.name,
        for (final exercise in block.exercises)
          [
            exercise.exerciseId,
            exercise.type.name,
            exercise.customSets,
            exercise.count.text,
            exercise.target.text,
            exercise.amrapRepetitions.text,
            exercise.rest.text,
            exercise.load.text,
            exercise.rir.text,
            exercise.amrapRir.text,
            for (final entry in exercise.variations.entries)
              // Mostrar campos que heredan los valores comunes no es una edición.
              if (entry.value.hasValues)
                [
                  entry.key,
                  entry.value.target.text,
                  entry.value.rest.text,
                  entry.value.load.text,
                  entry.value.rir.text,
                ],
          ],
      ],
  ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _running = widget.fixedRunningMode ?? true;
    _exercisePreferences = widget.exercisePreferences == null
        ? null
        : ExercisePreferencesController(widget.exercisePreferences!);
    if (widget.originalTemplate case final original?) _populate(original);
    if (widget.initialEditorState case final raw?) _restoreRaw(raw);
    if (widget.fixedRunningMode != null &&
        _running != widget.fixedRunningMode) {
      _workLoadError =
          'El borrador pertenece a otra modalidad. Se conserva sin modificar.';
    }
    if (widget.warmup) {
      _running = false;
      for (final block in _blocks) {
        block.format = WorkoutBlockFormat.straightSets;
      }
    }
    final binding = widget.workBinding;
    if (binding != null) {
      try {
        final state = binding.work.state;
        if (binding.work.discarded) {
          throw const FormatException('Este trabajo está descartado.');
        }
        if (state.isNotEmpty) {
          if (state['schema'] != 1) {
            throw const FormatException('Trabajo incompatible.');
          }
          binding.restoreContext(
            Map<String, dynamic>.from(state['context'] as Map),
          );
          _restoreRaw(Map<String, dynamic>.from(state['editor'] as Map));
        }
        _work = WorkoutEditorWorkController(
          binding,
          state.isEmpty ? _workState() : state,
        )..addListener(_workChanged);
        _observedWork = canonicalEditorState(
          state.isEmpty ? _workState() : state,
        );
      } catch (_) {
        _workLoadError = 'No se puede recuperar este trabajo con esta versión del editor. Se conserva sin sobrescribir.';
      }
    }
    if (_segments.length == 1 &&
        !_segments.single.manual &&
        _segments.single.target.text.isEmpty) {
      _expandedSegment = _segments.single;
    }
    _savedStamp = _draftStamp;
    if (widget.saveLocalDraft != null) {
      _observedWork = canonicalEditorState(_rawSnapshot());
    }
    widget
        .loadExercises()
        .then((items) {
          if (mounted) {
            setState(
              () => _catalog = {
                for (final item in items) item.id: item,
                for (final item in _catalog) item.id: item,
              }.values.toList(),
            );
          }
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() => _error = 'No se pudo cargar el catálogo.');
          }
        });
  }

  @override
  void didUpdateWidget(covariant WorkoutEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.exercisePreferences, widget.exercisePreferences)) {
      _exercisePreferences?.dispose();
      _exercisePreferences = widget.exercisePreferences == null
          ? null
          : ExercisePreferencesController(widget.exercisePreferences!);
    }
  }

  void _populate(WorkoutTemplate template) {
    _name.text = template.name;
    _description.text = template.description ?? '';
    _duration.text = template.estimatedDurationMinutes?.toString() ?? '';
    _running =
        template.blocks.length == 1 &&
        template.blocks.single.format == WorkoutBlockFormat.running;
    if (_running) {
      for (final segment in _segments) {
        segment.dispose();
      }
      _segments.clear();
      for (final set in template.blocks.single.items.single.sets) {
        if (_segments.isNotEmpty && _segments.last.matches(set)) {
          _segments.last.count.text =
              '${int.parse(_segments.last.count.text) + 1}';
        } else {
          _segments.add(_Segment.fromSet(set));
        }
      }
    } else {
      for (final block in _blocks) {
        block.dispose();
      }
      _blocks
        ..clear()
        ..addAll(template.blocks.map(_StrengthBlock.fromBlock));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workTimer?.cancel();
    _work?.dispose();
    _exercisePreferences?.dispose();
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    for (final segment in _segments) {
      segment.dispose();
    }
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  CreatePersonalWorkoutInput _input() {
    if (_running &&
        _segments.any((s) => s.wantsPace && s.pace.text.trim().isEmpty)) {
      throw const FormatException('Indica el ritmo o selecciona Sin objetivo.');
    }
    return projectWorkoutEditorSnapshot(WorkoutEditorSnapshot(_rawSnapshot()));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _invalidSegment = null);
    FocusScope.of(context).unfocus();
    try {
      if (_work?.finalizing == true) {
        setState(() {
          _busy = true;
          _error = null;
        });
        await _work!.flush();
        await _work!.finish(
          beforeAcknowledge: () {
            if (mounted) setState(() => _busy = false);
          },
        );
        return;
      }
      final input = _input();
      validateWorkoutDraft(input);
      setState(() {
        _busy = true;
        _error = null;
      });
      if (_work case final work?) {
        if (!await _saveWork()) throw StateError('Trabajo pendiente');
        final state = _workState(intent: workoutDraftToJson(input));
        work.update(state);
        await work.flush();
        await work.finish(
          beforeAcknowledge: () {
            if (mounted) setState(() => _busy = false);
          },
        );
        return;
      }
      _workTimer?.cancel();
      try {
        await _localWrite;
      } catch (_) {
        /* Guardar la receta sigue permitido. */
      }
      final savedId = await widget.onSave(input);
      if (mounted) {
        setState(() {
          _localFinalized = true;
          _busy = false;
          _savedStamp = _draftStamp;
        });
        widget.onSaved(savedId);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        _openInvalidRunningSegment();
      }
    } catch (error) {
      if (_work?.finalizing == true &&
          widget.workBinding!.definitiveError(error)) {
        _canReopen = true;
      }
      if (mounted) {
        setState(() => _error = widget.saveErrorMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _runningEstimate() {
    if (!_running ||
        _segments.any(
          (segment) => !segment.manual && segment.target.text.trim().isEmpty,
        )) {
      return null;
    }
    try {
      final input = _input();
      final estimate = estimateRunningWorkout(
        input.blocks.single.exercises.single.sets,
      );
      if (!estimate.isComplete) {
        return _segments.any((s) => s.manual)
            ? 'Duración abierta: hay pasos hasta avance manual.'
            : 'Completa los ritmos para calcular la duración.';
      }
      final low = (estimate.minimumSeconds / 60).round();
      final high = (estimate.maximumSeconds / 60).round();
      return low == high
          ? 'Duración estimada: $low min'
          : 'Duración estimada: $low min–$high min';
    } on FormatException {
      return null;
    }
  }

  int get _runningCount =>
      _segments.fold(0, (sum, s) => sum + (int.tryParse(s.count.text) ?? 0));

  void _applyRunningAction(
    WorkoutEditorSnapshot snapshot, {
    int? expandedIndex,
  }) {
    final next = [
      for (final row in snapshot.value['segments'] as List)
        _Segment.fromRaw(row as Map),
    ];
    setState(() {
      for (final old in _segments) {
        old.dispose();
      }
      _segments
        ..clear()
        ..addAll(next);
      _expandedSegment = expandedIndex == null ? null : next[expandedIndex];
      _invalidSegment = null;
      _separateRepetitions.clear();
      _groupBreaks.clear();
      _error = null;
    });
  }

  Future<void> _repeatGroup() async {
    final snapshot = WorkoutEditorSnapshot(_rawSnapshot());
    final groups = _runningGroups;
    var count = '2';
    var first = groups.indexWhere(
      (g) =>
          _segments[g.first].kind != RunningStepKind.warmup &&
          _segments[g.first].kind != RunningStepKind.cooldown,
    );
    if (first < 0) first = 0;
    var last = groups.lastIndexWhere(
      (g) =>
          _segments[g.first].kind != RunningStepKind.warmup &&
          _segments[g.first].kind != RunningStepKind.cooldown,
    );
    if (last < first) last = first;
    var omit = false;
    String? error;
    final result = await showDialog<WorkoutEditorSnapshot>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final canOmit = canOmitRunningGroupRecovery(
            snapshot,
            first: groups[first].first,
            last: groups[last].last,
          );
          return AlertDialog(
            title: const Text('Repetir grupo'),
            constraints: const BoxConstraints(maxWidth: 560),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            actionsPadding: const EdgeInsets.all(16),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Repite estos tramos en orden. Cada serie conserva su recuperación.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey('group-first-$first'),
                  initialValue: first,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: 'Desde tramo',
                    helperText:
                        (_segments[groups[first].first].kind ??
                                RunningStepKind.run)
                            .label,
                    helperMaxLines: 2,
                  ),
                  items: [
                    for (var i = 0; i < groups.length; i++)
                      DropdownMenuItem(value: i, child: Text('Tramo ${i + 1}')),
                  ],
                  onChanged: (value) => update(() {
                    if (value == null) return;
                    first = value;
                    if (last < first) last = first;
                    omit = false;
                    error = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey('group-last-$last'),
                  initialValue: last,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: 'Hasta tramo',
                    helperText:
                        (_segments[groups[last].first].kind ??
                                RunningStepKind.run)
                            .label,
                    helperMaxLines: 2,
                  ),
                  items: [
                    for (var i = first; i < groups.length; i++)
                      DropdownMenuItem(value: i, child: Text('Tramo ${i + 1}')),
                  ],
                  onChanged: (value) => update(() {
                    if (value == null) return;
                    last = value;
                    omit = false;
                    error = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: count,
                  onChanged: (value) => count = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Veces',
                    helperText: 'Incluye la primera vuelta.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Omitir última recuperación'),
                  subtitle: Text(
                    canOmit
                        ? 'Solo se omite al terminar la última vuelta.'
                        : 'El grupo debe terminar en una recuperación.',
                  ),
                  value: omit,
                  onChanged: canOmit
                      ? (value) => update(() => omit = value ?? false)
                      : null,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final next = repeatRunningEditorGroup(
                      snapshot,
                      first: groups[first].first,
                      last: groups[last].last,
                      repetitions: int.tryParse(count) ?? 0,
                      omitLastRecovery: omit,
                    );
                    Navigator.pop(dialogContext, next);
                  } on FormatException catch (failure) {
                    update(() => error = failure.message);
                  }
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) _applyRunningAction(result);
  }

  Future<void> _addPyramid() async {
    var distances = '200, 400, 600, 400, 200';
    final values = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear pirámide'),
        content: TextFormField(
          autofocus: true,
          initialValue: distances,
          decoration: const InputDecoration(
            labelText: 'Distancias en metros',
            helperText: 'Ejemplo: 200, 400, 600, 400, 200',
          ),
          onChanged: (value) => distances = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = distances
                  .split(',')
                  .map((part) => int.tryParse(part.trim()))
                  .toList();
              if (parsed.isEmpty ||
                  parsed.length > 40 ||
                  parsed.any((value) => value == null || value <= 0)) {
                return;
              }
              Navigator.of(dialogContext).pop(parsed.cast<int>());
            },
            child: const Text('Añadir tramos'),
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    final total = _segments.fold<int>(
      0,
      (sum, segment) => sum + (int.tryParse(segment.count.text) ?? 1),
    );
    if (total + values.length > 40) {
      setState(() => _error = 'La carrera no puede superar 40 tramos.');
      return;
    }
    setState(() {
      for (final distance in values) {
        _segments.add(_Segment()..target.text = '$distance');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El guardado final ya espera a los borradores pendientes. No encolar uno
    // nuevo al suspender durante esa operación: podría resucitarlo tras limpiarlo.
    if (_busy || _localFinalized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_work != null || widget.saveLocalDraft != null) {
        unawaited(_saveWork());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeWork();
    if (_workLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_workLoadError!),
        ),
      );
    }
    return WorkflowDraftGuard(
      hasUnsavedChanges: () => _draftStamp != _savedStamp,
      isBusy: () => _busy || _creatingExercise,
      saveDraftBeforeExit: _work == null && widget.saveLocalDraft == null
          ? null
          : _saveBeforeExit,
      child: AbsorbPointer(
        absorbing: _busy || _creatingExercise,
        child: _work?.finalizing == true
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_workStatus(), if (_error != null) Text(_error!)],
                ),
              )
            : _buildPage(context),
      ),
    );
  }

  Widget _buildPage(BuildContext context) => widget.embedded
      ? _editorContent()
      : Scaffold(
          appBar: AppBar(
            leading: widget.onClose == null
                ? null
                : IconButton(
                    tooltip: 'Volver',
                    onPressed: _busy ? null : widget.onClose,
                    icon: const Icon(Icons.arrow_back),
                  ),
            toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24
                ? 128
                : null,
            title: Text(
              MediaQuery.sizeOf(context).width < 600
                  ? widget.title
                  : widget.wideTitle ?? widget.title,
              softWrap: true,
              maxLines: 3,
            ),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: _editorContent(),
          ),
        );

  Widget _editorContent() {
    final children = <Widget>[
      Text(
        widget.heading,
        style: widget.embedded
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(widget.instructions),
      const SizedBox(height: 24),
      if (_work != null) _workStatus(),
      TextField(
        key: const ValueKey('workout-name'),
        controller: _name,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nombre de la sesión'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _description,
        maxLength: 500,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Indicaciones (opcional)'),
      ),
      const SizedBox(height: 12),
      if (!widget.warmup && widget.fixedRunningMode == null)
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: true, label: Text('Carrera')),
            ButtonSegment(value: false, label: Text('Fuerza')),
          ],
          selected: {_running},
          onSelectionChanged: (selection) =>
              setState(() => _running = selection.first),
        ),
      ?widget.additionalFields,
      const SizedBox(height: 20),
      if (_running) _runningEditor() else _strengthEditor(),
      if (_error != null && _invalidSegment == null) ...[
        const SizedBox(height: 16),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_busy ? 'Guardando…' : widget.saveLabel),
        ),
      ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: widget.embedded
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              )
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                children: children,
              ),
      ),
    );
  }

  List<RunningEditorGroup> get _runningGroups => runningEditorGroups(
    WorkoutEditorSnapshot(_rawSnapshot()),
    separateRepetitions: {
      for (var i = 0; i < _segments.length; i++)
        if (_separateRepetitions.contains(_segments[i])) i,
    },
    breakBefore: {
      for (var i = 0; i < _segments.length; i++)
        if (_groupBreaks.contains(_segments[i])) i,
    },
  );

  void _copySegment(_Segment source, _Segment target) {
    target.target.text = source.target.text;
    target.pace.text = source.pace.text;
    target.paceMax.text = source.paceMax.text;
    target.recoveryTime.text = source.recoveryTime.text;
    target.kind = source.kind;
    target.manual = source.manual;
    target.byDistance = source.byDistance;
    target.recovery = source.recovery;
    target.recoveryByDistance = source.recoveryByDistance;
    target.paceEnabled = source.paceEnabled;
  }

  void _editGrouped(
    List<int> indices,
    void Function(_Segment) edit, {
    bool omitLastRecovery = false,
  }) {
    setState(() {
      final first = _segments[indices.first];
      edit(first);
      for (final index in indices.skip(1)) {
        _copySegment(first, _segments[index]);
        if (omitLastRecovery && index == indices.last) {
          _segments[index].recovery = null;
        }
      }
      _invalidSegment = null;
    });
  }

  void _paceMode(
    List<int> indices,
    bool value, {
    bool omitLastRecovery = false,
  }) => _editGrouped(indices, (s) {
    s.paceEnabled = value;
    if (!value) {
      s.pace.clear();
      s.paceMax.clear();
    }
  }, omitLastRecovery: omitLastRecovery);

  void _addRunningSegment(int index) => setState(() {
    final next = _Segment();
    _segments.insert(index, next);
    _expandedSegment = next;
    _groupBreaks.add(next);
    _invalidSegment = null;
  });

  void _expandRecovery(
    RunningEditorGroup group, {
    bool pace = false,
    bool manual = false,
  }) {
    FocusScope.of(context).unfocus();
    if (pace &&
        _segments[group.first].recovery == RunningRecoveryType.passive) {
      return;
    }
    try {
      var next = WorkoutEditorSnapshot(_rawSnapshot());
      // La recuperación se representa con los mismos pasos V2 de siempre,
      // pero la presentación conserva cada pareja dentro de su serie.
      for (final index in group.work.reversed) {
        if (_segments[index].recovery == null) continue;
        next = separateRunningEditorRecovery(next, index);
      }
      _applyRunningAction(next, expandedIndex: group.first);
      final paired = _runningGroups.firstWhere((g) => g.first == group.first);
      if (pace) _paceMode(paired.recovery, true);
      if (manual) {
        _editGrouped(paired.recovery, (s) {
          s.manual = true;
          s.byDistance = false;
        });
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _repeatRunningRow(RunningEditorGroup group) async {
    var count = '${group.repetitions}';
    var omit = group.omitLastRecovery;
    String? error;
    final next = await showDialog<WorkoutEditorSnapshot>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Repeticiones del tramo'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: count,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Veces'),
                onChanged: (v) => count = v,
              ),
              if (group.paired || _segments[group.first].recovery != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Omitir última recuperación'),
                  value: omit,
                  onChanged: (v) => update(() => omit = v ?? false),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.pop(
                    dialogContext,
                    resizeRunningEditorGroup(
                      WorkoutEditorSnapshot(_rawSnapshot()),
                      group,
                      int.tryParse(count) ?? 0,
                      omitLastRecovery: omit,
                    ),
                  );
                } on FormatException catch (failure) {
                  update(() => error = failure.message);
                }
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (next != null && mounted) {
      _applyRunningAction(next, expandedIndex: group.first);
    }
  }

  void _runningMenu(
    String action,
    RunningEditorGroup group,
    int row,
    List<RunningEditorGroup> groups,
  ) {
    FocusScope.of(context).unfocus();
    try {
      switch (action) {
        case 'add':
          _addRunningSegment(group.last + 1);
        case 'repeat':
          unawaited(_repeatRunningRow(group));
        case 'duplicate':
          _applyRunningAction(
            duplicateRunningEditorGroup(
              WorkoutEditorSnapshot(_rawSnapshot()),
              group,
            ),
            expandedIndex: group.last + 1,
          );
          _groupBreaks.add(_segments[group.last + 1]);
          final after = group.last + 1 + group.last - group.first + 1;
          if (after < _segments.length) _groupBreaks.add(_segments[after]);
        case 'separate':
          final length = group.last - group.first + 1;
          _applyRunningAction(
            repeatRunningEditorGroup(
              WorkoutEditorSnapshot(_rawSnapshot()),
              first: group.first,
              last: group.last,
              repetitions: 1,
            ),
            expandedIndex: group.first,
          );
          final expandedLength = group.paired ? length : group.repetitions;
          _separateRepetitions.addAll(
            _segments.sublist(group.first, group.first + expandedLength),
          );
        case 'up':
          _applyRunningAction(
            moveRunningEditorGroup(
              WorkoutEditorSnapshot(_rawSnapshot()),
              group,
              groups[row - 1],
            ),
            expandedIndex: groups[row - 1].first,
          );
        case 'down':
          final next = groups[row + 1];
          _applyRunningAction(
            moveRunningEditorGroup(
              WorkoutEditorSnapshot(_rawSnapshot()),
              group,
              next,
            ),
            expandedIndex: group.first + next.last - next.first + 1,
          );
        case 'remove':
          setState(() {
            for (final segment in _segments.sublist(
              group.first,
              group.last + 1,
            )) {
              if (_expandedSegment == segment) _expandedSegment = null;
              _separateRepetitions.remove(segment);
              _groupBreaks.remove(segment);
              segment.dispose();
            }
            _segments.removeRange(group.first, group.last + 1);
          });
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  String _measureSummary(_Segment s) => s.manual
      ? 'Hasta Lap'
      : s.target.text.trim().isEmpty
      ? 'Completa ${s.byDistance ? 'la distancia' : 'el tiempo'}'
      : '${s.target.text}${s.byDistance ? ' m' : ' min'}';
  String _paceSummary(_Segment s) => s.pace.text.trim().isEmpty
      ? (s.wantsPace ? 'Completa el ritmo' : 'Sin objetivo')
      : '${s.pace.text}${s.paceMax.text.isNotEmpty && s.paceMax.text != s.pace.text ? '–${s.paceMax.text}' : ''} min/km';
  String _runningSummary(RunningEditorGroup group) {
    final work = _segments[group.first];
    final main = '${_measureSummary(work)} · ${_paceSummary(work)}';
    if (group.paired) {
      final soft = _segments[group.recovery.first];
      return '$main\nRec. ${_measureSummary(soft)} · ${_paceSummary(soft)}${group.omitLastRecovery ? ' · sin última rec.' : ''}';
    }
    return work.recovery == null
        ? main
        : '$main\nRec. ${work.recoveryTime.text}${work.recoveryByDistance ? ' m' : ' min'} · ${work.recovery!.name == 'passive'
              ? 'Pasiva'
              : work.recovery == RunningRecoveryType.walking
              ? 'Andando'
              : 'Trote'}${group.omitLastRecovery ? ' · sin última rec.' : ''}';
  }

  Color _runningColor(RunningStepKind kind) => switch (kind) {
    RunningStepKind.warmup => Colors.orange.shade300,
    RunningStepKind.cooldown => Colors.teal.shade300,
    RunningStepKind.run => Theme.of(context).colorScheme.primary,
    _ => Theme.of(context).colorScheme.outline,
  };

  Widget _runningFields(RunningEditorGroup group, {bool recovery = false}) {
    final indices = recovery ? group.recovery : group.work;
    final s = _segments[indices.first];
    final kind = s.kind ?? RunningStepKind.run;
    void edit(void Function(_Segment) change) => _editGrouped(
      indices,
      change,
      omitLastRecovery: !recovery && group.omittedAttachedRecovery,
    );
    return RunningStepFields(
      key: ValueKey('${recovery ? 'recovery' : 'work'}-fields-${group.first}'),
      adminLabels: true,
      compact: true,
      stepKind: kind,
      kindLabel: 'Tipo de paso',
      objectiveLabel: 'Objetivo',
      stepKindOptions: recovery
          ? const [
              RunningStepKind.recovery,
              RunningStepKind.rest,
              RunningStepKind.walking,
              RunningStepKind.jogging,
            ]
          : null,
      showRecovery:
          !recovery &&
          (s.recovery != null ||
              !const [
                RunningStepKind.rest,
                RunningStepKind.recovery,
              ].contains(kind)),
      onStepKindChanged: (value) => edit((s) {
        s.kind = value;
        if (value == RunningStepKind.rest) {
          s.byDistance = false;
          s.target.text = '01:00';
          s.pace.clear();
          s.paceMax.clear();
          s.paceEnabled = false;
        }
      }),
      targetType: s.manual
          ? WorkoutTargetType.manual
          : s.byDistance
          ? WorkoutTargetType.distance
          : WorkoutTargetType.duration,
      targetController: s.target,
      paceMinController: s.pace,
      paceMaxController: s.paceMax,
      paceEnabled: s.wantsPace,
      onPaceModeChanged: (value) => _paceMode(
        indices,
        value,
        omitLastRecovery: !recovery && group.omittedAttachedRecovery,
      ),
      recoveryType: s.recovery,
      recoveryByDistance: s.recoveryByDistance,
      recoveryController: s.recoveryTime,
      onEdited: () => edit((_) {}),
      onTargetTypeChanged: (value) => edit((s) {
        s.manual = value == WorkoutTargetType.manual;
        s.byDistance = value == WorkoutTargetType.distance;
        s.target.text = s.byDistance ? '1000' : '20:00';
      }),
      onRecoveryTypeChanged: (value) => edit((s) {
        s.recovery = value;
        if (value == RunningRecoveryType.passive) {
          s.recoveryByDistance = false;
          s.recoveryTime.text = '01:00';
        } else if (value != null && s.recoveryTime.text.isEmpty) {
          s.recoveryTime.text = '01:00';
        }
      }),
      onRecoveryMeasureChanged: (value) => edit((s) {
        s.recoveryByDistance = value;
        s.recoveryTime.text = value ? '200' : '01:00';
      }),
      onRecoveryPaceModeChanged:
          recovery ||
              const [
                RunningStepKind.rest,
                RunningStepKind.recovery,
              ].contains(kind)
          ? null
          : (value) {
              if (value) _expandRecovery(group, pace: true);
            },
      onRecoveryTargetTypeChanged:
          recovery ||
              const [
                RunningStepKind.rest,
                RunningStepKind.recovery,
              ].contains(kind)
          ? null
          : (value) {
              if (value == WorkoutTargetType.manual) {
                _expandRecovery(group, manual: true);
              } else {
                edit((s) {
                  s.recoveryByDistance = value == WorkoutTargetType.distance;
                  s.recoveryTime.text = s.recoveryByDistance ? '200' : '01:00';
                });
              }
            },
      recoveryEditor: !recovery && group.paired
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recuperación',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            for (final index in group.recovery.reversed) {
                              _segments.removeAt(index).dispose();
                            }
                          }),
                          child: const Text('Quitar'),
                        ),
                      ],
                    ),
                    _runningFields(group, recovery: true),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _openInvalidRunningSegment() {
    if (!_running) return;
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      try {
        if (segment.wantsPace && segment.pace.text.trim().isEmpty) {
          throw const FormatException('Ritmo incompleto');
        }
        validateWorkoutDraft(
          projectWorkoutEditorSnapshot(
            WorkoutEditorSnapshot({
              ..._rawSnapshot(),
              'nameText': 'Comprobar tramo',
              'segments': [segment.raw],
            }),
          ),
        );
      } on FormatException {
        final group = _runningGroups.firstWhere(
          (g) => i >= g.first && i <= g.last,
        );
        setState(() {
          _expandedSegment = _segments[group.first];
          _invalidSegment = segment;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _segments[group.first].anchor.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 180),
              alignment: .1,
            );
          }
        });
        break;
      }
    }
  }

  bool _runningGroupExpanded(RunningEditorGroup group) {
    final index = _expandedSegment == null
        ? -1
        : _segments.indexOf(_expandedSegment!);
    return index >= group.first && index <= group.last;
  }

  void _reorderRunning(int from, int to) {
    if (_busy || from == to) return;
    final groups = _runningGroups;
    if (from < 0 || to < 0 || from >= groups.length || to >= groups.length) {
      return;
    }
    final chunks = [
      for (final group in groups)
        _segments.sublist(group.first, group.last + 1),
    ];
    final moved = chunks.removeAt(from);
    chunks.insert(to, moved);
    setState(() {
      // Mover los controladores conserva texto incompleto, foco lógico y las
      // excepciones. La receta solo cambia su orden al aceptar el destino.
      _segments
        ..clear()
        ..addAll(chunks.expand((chunk) => chunk));
      _groupBreaks
        ..clear()
        ..addAll(chunks.map((chunk) => chunk.first));
    });
  }

  Widget _runningDragFeedback(BuildContext context, int row) {
    final group = _runningGroups[row];
    final kind = _segments[group.first].kind ?? RunningStepKind.run;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _runningColor(kind), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind.label}${group.repetitions > 1 ? ' × ${group.repetitions}' : ''}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            _runningSummary(group),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _runningEditor() {
    final groups = _runningGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tramos de carrera',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text('$_runningCount/40'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Arrastra el asa para ordenar. Las series iguales se editan juntas.',
        ),
        const SizedBox(height: 8),
        RunningReorderableSteps(
          identities: [for (final group in groups) _segments[group.first]],
          enabled: !_busy,
          onReorder: _reorderRunning,
          feedbackBuilder: _runningDragFeedback,
          itemBuilder: (context, row, handle) => RunningStepCard(
            dragHandle: handle,
            key: _segments[groups[row].first].anchor,
            index: row,
            title:
                '${(_segments[groups[row].first].kind ?? RunningStepKind.run).label}${groups[row].repetitions > 1 ? ' × ${groups[row].repetitions}' : ''}',
            summary: _runningSummary(groups[row]),
            color: _runningColor(
              _segments[groups[row].first].kind ?? RunningStepKind.run,
            ),
            expanded: _runningGroupExpanded(groups[row]),
            onToggle: () {
              FocusScope.of(context).unfocus();
              setState(
                () => _expandedSegment = _runningGroupExpanded(groups[row])
                    ? null
                    : _segments[groups[row].first],
              );
            },
            menu: PopupMenuButton<String>(
              key: ValueKey('running-step-menu-$row'),
              tooltip: 'Opciones del tramo ${row + 1}',
              onSelected: (action) =>
                  _runningMenu(action, groups[row], row, groups),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'add',
                  enabled: _runningCount < 40,
                  child: const Text('Añadir debajo'),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  enabled:
                      _runningCount +
                          groups[row].repetitions *
                              (groups[row].paired ? 2 : 1) -
                          (groups[row].paired && groups[row].omitLastRecovery
                              ? 1
                              : 0) <=
                      40,
                  child: const Text('Duplicar tramo'),
                ),
                const PopupMenuItem(
                  value: 'repeat',
                  child: Text('Cambiar repeticiones'),
                ),
                if (groups[row].repetitions > 1)
                  const PopupMenuItem(
                    value: 'separate',
                    child: Text('Editar repeticiones por separado'),
                  ),
                PopupMenuItem(
                  value: 'up',
                  enabled: row > 0,
                  child: const Text('Subir tramo'),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: row < groups.length - 1,
                  child: const Text('Bajar tramo'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  enabled: groups.length > 1,
                  child: const Text('Eliminar tramo'),
                ),
              ],
            ),
            editor: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (groups[row].paired || groups[row].work.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: ValueKey('running-repeat-$row'),
                      onPressed: () => _repeatRunningRow(groups[row]),
                      icon: const Icon(Icons.repeat),
                      label: Text(
                        '${groups[row].repetitions} ${groups[row].repetitions == 1 ? 'vez' : 'veces'}',
                      ),
                    ),
                  )
                else
                  _field(
                    _segments[groups[row].first].count,
                    'Veces',
                    110,
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: 12),
                _runningFields(groups[row]),
                if (_invalidSegment != null &&
                    groups[row].first <= _segments.indexOf(_invalidSegment!) &&
                    groups[row].last >= _segments.indexOf(_invalidSegment!))
                  Text(
                    _error ?? 'Revisa este tramo.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _expandedSegment = null);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _runningCount >= 40
                  ? null
                  : () => _addRunningSegment(_segments.length),
              icon: const Icon(Icons.add),
              label: const Text('Añadir tramo distinto'),
            ),
            TextButton.icon(
              onPressed: () => _repeatRunningRow(groups.last),
              icon: const Icon(Icons.repeat),
              label: const Text('Repetir último'),
            ),
            TextButton.icon(
              onPressed: _repeatGroup,
              icon: const Icon(Icons.repeat),
              label: const Text('Repetir grupo'),
            ),
            TextButton.icon(
              onPressed: _addPyramid,
              icon: const Icon(Icons.stacked_line_chart),
              label: const Text('Crear pirámide'),
            ),
          ],
        ),
        if (_runningEstimate() case final estimate?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(estimate),
          ),
      ],
    );
  }

  Widget _strengthEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Bloques de fuerza y acondicionamiento',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Organiza el trabajo en bloques. El formato define series, rondas y descansos.',
      ),
      const SizedBox(height: 12),
      if (_catalog.isEmpty) Text(widget.emptyCatalogMessage),
      for (var i = 0; i < _blocks.length; i++)
        Card(
          key: ValueKey(_blocks[i]),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _strengthBlock(i, _blocks[i]),
          ),
        ),
      TextButton.icon(
        key: const ValueKey('add-workout-block'),
        onPressed: _blocks.length >= 10
            ? null
            : () => setState(() => _blocks.add(_StrengthBlock())),
        icon: const Icon(Icons.add),
        label: const Text('Añadir bloque'),
      ),
      const SizedBox(height: 12),
      _field(_duration, 'Duración estimada (min, opcional)', 265),
    ],
  );

  Widget _strengthBlock(int index, _StrengthBlock block) {
    final format = block.format;
    final usesRounds =
        format == WorkoutBlockFormat.superset ||
        format == WorkoutBlockFormat.circuit ||
        format == WorkoutBlockFormat.intervals ||
        format == WorkoutBlockFormat.emom;
    final canAddExercise =
        format != WorkoutBlockFormat.tabata &&
        format != WorkoutBlockFormat.intervals &&
        format != WorkoutBlockFormat.superset &&
        block.exercises.length < 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rowTitle(
          'Bloque ${index + 1}',
          _blocks.length > 1
              ? () => setState(() => _blocks.removeAt(index).dispose())
              : null,
          duplicate: _blocks.length >= 10
              ? null
              : () => setState(() => _blocks.insert(index + 1, block.clone())),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _field(block.name, 'Nombre del bloque', 230),
            if (!widget.warmup)
              SizedBox(
                width: 265,
                child: WorkoutFormatField(
                  format: format,
                  exerciseCount: block.exercises
                      .where((exercise) => !exercise.isEmptyFormatSlot)
                      .length,
                  label: 'Formato',
                  onChanged: (value) {
                    setState(() {
                      // Las posiciones automáticas vacías pertenecen al formato,
                      // no son ejercicios añadidos por el usuario. Una posición
                      // elegida o modificada se conserva siempre.
                      final unused = block.exercises
                          .where((exercise) => exercise.isEmptyFormatSlot)
                          .toList();
                      block.exercises.removeWhere(unused.contains);
                      for (final exercise in unused) {
                        exercise.dispose();
                      }
                      block.format = value;
                      final minimum = value == WorkoutBlockFormat.tabata
                          ? 8
                          : value == WorkoutBlockFormat.superset ||
                                value == WorkoutBlockFormat.circuit
                          ? 2
                          : 1;
                      while (block.exercises.length < minimum) {
                        block.exercises.add(_Exercise(automaticSlot: true));
                      }
                    });
                  },
                ),
              ),
            if (usesRounds)
              _field(
                block.rounds,
                'Rondas',
                100,
                onChanged: (_) => setState(() {}),
              ),
            if (format == WorkoutBlockFormat.superset ||
                format == WorkoutBlockFormat.circuit ||
                format == WorkoutBlockFormat.intervals)
              _field(block.rest, 'Descanso entre rondas (m:ss)', 230),
            if (format == WorkoutBlockFormat.amrap)
              _field(block.cap, 'Límite global (m:ss)', 190),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formatHelp(format),
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        if ((format == WorkoutBlockFormat.tabata ||
                format == WorkoutBlockFormat.amrap) &&
            block.exercises.any((item) => item.customSets))
          const Text(
            'Los ajustes por serie no se aplican en este formato. Puedes recuperarlos volviendo al formato anterior antes de guardar.',
          ),
        if (format == WorkoutBlockFormat.amrap &&
            block.exercises.any(
              (item) => item.type != WorkoutTargetType.repetitions,
            ))
          const Text(
            'AMRAP necesita un objetivo de repeticiones. Los tiempos y distancias anteriores se conservan mientras editas; no se convierten en repeticiones.',
          ),
        const SizedBox(height: 12),
        for (var j = 0; j < block.exercises.length; j++)
          Padding(
            key: ValueKey(block.exercises[j]),
            padding: const EdgeInsets.only(bottom: 12),
            child: _strengthExercise(block, j),
          ),
        if (canAddExercise)
          TextButton.icon(
            onPressed: () => setState(() => block.exercises.add(_Exercise())),
            icon: const Icon(Icons.add),
            label: const Text('Añadir ejercicio o estación'),
          ),
      ],
    );
  }

  Widget _strengthExercise(_StrengthBlock block, int index) {
    final item = block.exercises[index];
    final format = block.format;
    final fixedRounds = format != WorkoutBlockFormat.straightSets;
    final tabata = format == WorkoutBlockFormat.tabata;
    final amrap = format == WorkoutBlockFormat.amrap;
    final targetType = amrap ? WorkoutTargetType.repetitions : item.type;
    final targetInput = item.targetFor(format);
    final rirInput = item.rirFor(format);
    final canRemove = tabata
        ? block.exercises.length > 8
        : block.exercises.length > 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tabata
                      ? 'Intervalo ${index + 1}'
                      : format == WorkoutBlockFormat.superset
                      ? 'A${index + 1}'
                      : 'Posición ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (block.format != WorkoutBlockFormat.tabata &&
                  block.format != WorkoutBlockFormat.intervals &&
                  block.format != WorkoutBlockFormat.superset &&
                  block.exercises.length < 20)
                IconButton(
                  tooltip: 'Duplicar posición',
                  onPressed: () => setState(
                    () => block.exercises.insert(index + 1, item.clone()),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                ),
              if (index > 0)
                IconButton(
                  tooltip: 'Subir posición',
                  onPressed: () => setState(() {
                    final previous = block.exercises[index - 1];
                    block.exercises[index - 1] = item;
                    block.exercises[index] = previous;
                  }),
                  icon: const Icon(Icons.arrow_upward),
                ),
              if (index < block.exercises.length - 1)
                IconButton(
                  tooltip: 'Bajar posición',
                  onPressed: () => setState(() {
                    final next = block.exercises[index + 1];
                    block.exercises[index + 1] = item;
                    block.exercises[index] = next;
                  }),
                  icon: const Icon(Icons.arrow_downward),
                ),
              if (canRemove)
                IconButton(
                  tooltip: 'Quitar posición',
                  onPressed: () =>
                      setState(() => block.exercises.removeAt(index).dispose()),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _catalog.isEmpty && widget.onCreateExercise == null
                ? null
                : () async {
                    final selected = await _chooseExercise();
                    if (selected != null && mounted) {
                      setState(() => item.exerciseId = selected.id);
                      _exercisePreferences?.recordSelection(selected.id);
                    }
                  },
            icon: item.exerciseId == null
                ? const Icon(Icons.search)
                : ExerciseThumbnail(
                    url: _catalog
                        .where((exercise) => exercise.id == item.exerciseId)
                        .firstOrNull
                        ?.thumbnailUrl,
                    size: 28,
                  ),
            label: Text(
              item.exerciseId == null
                  ? 'Buscar ejercicio del catálogo'
                  : 'Cambiar ejercicio · ${_catalog.where((exercise) => exercise.id == item.exerciseId).map((exercise) => exercise.name).firstOrNull ?? 'Buscar ejercicio del catálogo'}',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              if (!fixedRounds)
                _field(
                  item.count,
                  'Series',
                  100,
                  onChanged: (_) => setState(() {}),
                ),
              if (!tabata && !amrap)
                SizedBox(
                  width: 225,
                  child: CompactFieldLayout(
                    label: 'Objetivo',
                    child: DropdownButtonFormField<WorkoutTargetType>(
                      isExpanded: true,
                      key: ValueKey(item.type),
                      initialValue: item.type,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontSize: 16),
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: WorkoutTargetType.repetitions,
                          child: Text('Repeticiones'),
                        ),
                        DropdownMenuItem(
                          value: WorkoutTargetType.duration,
                          child: Text('Duración'),
                        ),
                        DropdownMenuItem(
                          value: WorkoutTargetType.distance,
                          child: Text('Metros'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => item.type = value ?? item.type),
                    ),
                  ),
                ),
            ],
          ),
          if (tabata)
            const Padding(
              padding: EdgeInsets.only(top: 15),
              child: Text('20 s de trabajo · 10 s de recuperación'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.customSets)
                    Text(
                      'Valores comunes',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  StrengthSetFields(
                    targetType: targetType,
                    targetText: targetInput.text,
                    restText: item.rest.text,
                    loadText: item.load.text,
                    rirText: rirInput.text,
                    targetLabel: targetType == WorkoutTargetType.duration
                        ? 'Tiempo'
                        : 'Cantidad',
                    restLabel: 'Descanso',
                    loadLabel: 'Carga',
                    rirLabel: 'RIR',
                    validateNumbers: false,
                    showRest:
                        !amrap &&
                        format != WorkoutBlockFormat.emom &&
                        format != WorkoutBlockFormat.intervals,
                    onTargetChanged: (value) => _changeExerciseValue(
                      item,
                      () => targetInput.text = value,
                    ),
                    onRestChanged: (value) => _changeExerciseValue(
                      item,
                      () => item.rest.text = value,
                    ),
                    onLoadChanged: (value) => _changeExerciseValue(
                      item,
                      () => item.load.text = value,
                    ),
                    onRirChanged: (value) =>
                        setState(() => rirInput.text = value),
                  ),
                ],
              ),
            ),
          if (!tabata && !amrap) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  setState(() => item.customSets = !item.customSets),
              icon: Icon(item.customSets ? Icons.expand_less : Icons.tune),
              label: Text(
                item.customSets
                    ? 'Ocultar objetivos por serie'
                    : 'Personalizar cada serie',
              ),
            ),
            if (item.customSets) ...[
              const Divider(height: 24),
              Text(
                'Ajustes por serie',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Rellena solo lo que cambie. «Común» usa el valor de arriba; no significa cero.',
              ),
              const SizedBox(height: 12),
              for (
                var setIndex = 0;
                setIndex <
                    (fixedRounds
                            ? int.tryParse(block.rounds.text) ?? 0
                            : int.tryParse(item.count.text) ?? 0)
                        .clamp(0, 20);
                setIndex++
              )
                _variationFields(item, setIndex, showRest: !fixedRounds),
            ],
          ],
        ],
      ),
    );
  }

  void _changeExerciseValue(_Exercise item, VoidCallback change) {
    final wasEmpty = item.isEmptyFormatSlot;
    change();
    // Actualizar los formatos disponibles al empezar a completar un hueco,
    // sin reconstruir todo el editor por cada dígito de una receta existente.
    if (wasEmpty != item.isEmptyFormatSlot) {
      setState(() {});
    }
  }

  Widget _variationFields(_Exercise item, int index, {required bool showRest}) {
    final variation = item.variations.putIfAbsent(index, _SetVariation.new);
    if (_work != null || widget.saveLocalDraft != null) {
      // Estas filas nacen durante build, después de observar los campos comunes.
      // Sus cambios deben guardar borrador aunque no provoquen otro rebuild.
      for (final field in [
        variation.target,
        variation.rest,
        variation.load,
        variation.rir,
      ]) {
        if (_observedControllers.add(field)) field.addListener(_queueWork);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Serie ${index + 1}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          StrengthSetFields(
            key: ValueKey(variation),
            targetType: item.type,
            targetText: variation.target.text,
            restText: variation.rest.text,
            loadText: variation.load.text,
            rirText: variation.rir.text,
            targetLabel: 'Objetivo',
            restLabel: 'Descanso',
            loadLabel: 'Carga',
            rirLabel: 'RIR',
            targetOptional: true,
            restOptional: true,
            inheritEmptyValues: true,
            validateNumbers: false,
            showRest: showRest,
            onTargetChanged: (value) => variation.target.text = value,
            onRestChanged: (value) => variation.rest.text = value,
            onLoadChanged: (value) => variation.load.text = value,
            onRirChanged: (value) => setState(() => variation.rir.text = value),
          ),
        ],
      ),
    );
  }

  Future<WorkoutEditorExercise?> _chooseExercise() async {
    final preferences = _exercisePreferences;
    var create = false;
    String? scope;
    final scopes = _catalog
        .map((e) => e.catalogScope)
        .whereType<String>()
        .toSet();
    if (scopes.contains('EntrenaOP') || scopes.contains('Míos')) {
      scopes.addAll({'EntrenaOP', 'Míos'});
    }
    final selected = await showDialog<WorkoutEditorExercise>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, changeScope) => AlertDialog(
          title: const Text('Buscar ejercicio'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          titlePadding: const EdgeInsets.all(16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          actionsPadding: const EdgeInsets.all(12),
          content: SizedBox(
            width: 480,
            height: 430,
            child: Column(
              children: [
                if (scopes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final label in <String?>[null, ...scopes])
                        ChoiceChip(
                          label: Text(label ?? 'Todos'),
                          selected: scope == label,
                          onSelected: (_) => changeScope(() => scope = label),
                        ),
                    ],
                  ),
                Expanded(
                  child: ExerciseSearchList<WorkoutEditorExercise>(
                    searchLabel: scopes.isEmpty
                        ? 'Buscar por nombre, músculo o material'
                        : 'Buscar',
                    exercises: scope == null
                        ? _catalog
                        : _catalog
                              .where((e) => e.catalogScope == scope)
                              .toList(),
                    idOf: (exercise) => exercise.id,
                    preferences: preferences,
                    nameOf: (exercise) => exercise.name,
                    searchTermsOf: (exercise) => [
                      exercise.name,
                      ...exercise.muscleGroups,
                      ...exercise.equipment,
                    ],
                    thumbnailOf: (exercise) => exercise.thumbnailUrl,
                    muscleGroupsOf: (exercise) => exercise.muscleGroups,
                    equipmentOf: (exercise) => exercise.equipment,
                    subtitleOf: (exercise) => [
                      ...exercise.muscleGroups,
                      ...exercise.equipment,
                    ].join(' · '),
                    onSelected: (exercise) =>
                        Navigator.of(dialogContext).pop(exercise),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (widget.onCreateExercise != null)
              TextButton.icon(
                onPressed: () {
                  create = true;
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear ejercicio'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || !identical(preferences, _exercisePreferences)) return null;
    if (!create) return selected;
    setState(() {
      _creatingExercise = true;
      _error = null;
    });
    try {
      final created = await widget.onCreateExercise!(context);
      if (!mounted || !identical(preferences, _exercisePreferences)) {
        return null;
      }
      if (created != null && mounted) {
        setState(
          () => _catalog = {
            for (final exercise in _catalog) exercise.id: exercise,
            created.id: created,
          }.values.toList(),
        );
      }
      return created;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo crear el ejercicio. La sesión conserva tus cambios.',
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _creatingExercise = false);
    }
  }

  String _formatHelp(WorkoutBlockFormat format) => switch (format) {
    WorkoutBlockFormat.straightSets =>
      'Cada ejercicio tiene sus propias series y descansos.',
    WorkoutBlockFormat.superset =>
      'Dos ejercicios alternados; una serie de cada uno por ronda.',
    WorkoutBlockFormat.circuit =>
      'Estaciones en orden; una pasada completa por ronda.',
    WorkoutBlockFormat.intervals =>
      'Un ejercicio repetido por rondas con descanso entre ellas.',
    WorkoutBlockFormat.emom =>
      'Cada estación ocupa un minuto; las rondas repiten la secuencia.',
    WorkoutBlockFormat.amrap =>
      'Tantas vueltas como sea posible hasta el límite global.',
    WorkoutBlockFormat.tabata =>
      'Ocho intervalos fijos de 20 s de trabajo y 10 s de recuperación.',
    _ => '',
  };

  Widget _rowTitle(
    String title,
    VoidCallback? remove, {
    VoidCallback? duplicate,
  }) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (duplicate != null)
        IconButton(
          tooltip: 'Duplicar bloque',
          onPressed: duplicate,
          icon: const Icon(Icons.copy_outlined),
        ),
      if (remove != null)
        IconButton(
          tooltip: 'Quitar',
          onPressed: remove,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    double width, {
    ValueChanged<String>? onChanged,
  }) {
    final clock = label.contains('m:ss');
    final text = label.startsWith('Nombre');
    final minutes = label.contains('(min, opcional)');
    final caption =
        (label.startsWith('Descanso entre rondas') ? 'Descanso' : label)
            .replaceAll(' (m:ss)', '')
            .replaceAll(' (min, opcional)', '');
    final painter = TextPainter(
      text: TextSpan(
        text: caption,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minimumWidth = painter.width + 24;
    painter.dispose();
    return SizedBox(
      width: width < minimumWidth ? minimumWidth : width,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.textScalerOf(context).scale(8),
        ),
        child: TextField(
          key: ValueKey('editor-field-$label'),
          controller: controller,
          onChanged: onChanged,
          keyboardType: text
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: clock ? const [DurationInputFormatter()] : null,
          decoration: InputDecoration(
            labelText: caption,
            hintText: clock ? '00:00' : null,
            helperText: label.startsWith('Descanso entre rondas')
                ? 'Entre rondas · min:seg'
                : clock
                ? 'min:seg'
                : minutes
                ? 'min · opcional'
                : null,
          ),
        ),
      ),
    );
  }
}

class _Segment {
  _Segment();
  final anchor = GlobalKey();
  bool paceEnabled = false;
  bool get wantsPace =>
      paceEnabled ||
      pace.text.trim().isNotEmpty ||
      paceMax.text.trim().isNotEmpty;

  factory _Segment.fromRaw(Map row) => _Segment()
    ..count.text = row['countText'] as String
    ..target.text = row['targetText'] as String
    ..pace.text = row['paceText'] as String
    ..paceMax.text = row['paceMaxText'] as String
    ..paceEnabled =
        (row['paceText'] as String).isNotEmpty ||
        (row['paceMaxText'] as String).isNotEmpty
    ..recoveryTime.text = row['recoveryTimeText'] as String
    ..kind = row['stepKind'] == null
        ? null
        : RunningStepKind.values.byName(row['stepKind'] as String)
    ..manual = row['manual'] == true
    ..byDistance = row['byDistance'] as bool
    ..recoveryByDistance = row['recoveryByDistance'] as bool
    ..recovery = row['recoveryType'] == null
        ? null
        : RunningRecoveryType.values.byName(row['recoveryType'] as String);

  Map<String, dynamic> get raw => {
    'countText': count.text,
    'targetText': target.text,
    'paceText': pace.text,
    'paceMaxText': paceMax.text,
    'recoveryTimeText': recoveryTime.text,
    'byDistance': byDistance,
    if (kind != null) 'stepKind': kind!.name,
    if (manual) 'manual': true,
    'recoveryByDistance': recoveryByDistance,
    'recoveryType': recovery?.name,
  };

  factory _Segment.fromSet(WorkoutSet set) {
    final segment = _Segment();
    segment.kind = set.runningStep?.kind;
    segment.manual =
        set.runningStep?.completion == RunningStepCompletion.manual;
    segment.byDistance = set.targetDistanceMeters != null;
    segment.target.text = set.targetDistanceMeters != null
        ? _number(set.targetDistanceMeters!)
        : _time(set.targetDurationSeconds ?? 0);
    segment.pace.text = set.targetPaceMinSecondsPerKm == null
        ? ''
        : _time(set.targetPaceMinSecondsPerKm!);
    segment.paceMax.text =
        set.targetPaceMaxSecondsPerKm == null ||
            set.targetPaceMaxSecondsPerKm == set.targetPaceMinSecondsPerKm
        ? ''
        : _time(set.targetPaceMaxSecondsPerKm!);
    segment.paceEnabled =
        segment.pace.text.isNotEmpty || segment.paceMax.text.isNotEmpty;
    segment.recovery = set.recoveryType;
    segment.recoveryByDistance = set.recoveryDistanceMeters != null;
    segment.recoveryTime.text = set.recoveryDistanceMeters != null
        ? _number(set.recoveryDistanceMeters!)
        : _time(set.recoveryDurationSeconds ?? 60);
    return segment;
  }

  bool matches(WorkoutSet set) =>
      kind == set.runningStep?.kind &&
      manual == (set.runningStep?.completion == RunningStepCompletion.manual) &&
      byDistance == (set.targetDistanceMeters != null) &&
      target.text ==
          (set.targetDistanceMeters != null
              ? _number(set.targetDistanceMeters!)
              : _time(set.targetDurationSeconds ?? 0)) &&
      pace.text ==
          (set.targetPaceMinSecondsPerKm == null
              ? ''
              : _time(set.targetPaceMinSecondsPerKm!)) &&
      paceMax.text ==
          (set.targetPaceMaxSecondsPerKm == null ||
                  set.targetPaceMaxSecondsPerKm == set.targetPaceMinSecondsPerKm
              ? ''
              : _time(set.targetPaceMaxSecondsPerKm!)) &&
      recovery == set.recoveryType &&
      recoveryByDistance == (set.recoveryDistanceMeters != null) &&
      recoveryTime.text ==
          (set.recoveryDistanceMeters != null
              ? _number(set.recoveryDistanceMeters!)
              : _time(set.recoveryDurationSeconds ?? 60));

  final count = TextEditingController(text: '1');
  final target = TextEditingController();
  final pace = TextEditingController();
  final paceMax = TextEditingController();
  final recoveryTime = TextEditingController(text: '01:00');
  RunningStepKind? kind = RunningStepKind.run;
  bool manual = false;
  bool byDistance = true;
  bool recoveryByDistance = false;
  RunningRecoveryType? recovery;

  void dispose() {
    count.dispose();
    target.dispose();
    pace.dispose();
    paceMax.dispose();
    recoveryTime.dispose();
  }
}

class _StrengthBlock {
  _StrengthBlock();

  _StrengthBlock clone() {
    final copy = _StrengthBlock();
    copy.name.text = name.text;
    copy.rounds.text = rounds.text;
    copy.rest.text = rest.text;
    copy.cap.text = cap.text;
    copy.format = format;
    copy.exercises.single.dispose();
    copy.exercises
      ..clear()
      ..addAll(exercises.map((e) => e.clone(preserveAutomaticSlot: true)));
    return copy;
  }

  factory _StrengthBlock.fromBlock(WorkoutBlock source) {
    final block = _StrengthBlock();
    block.name.text = source.name;
    block.format = source.format;
    block.rounds.text = source.rounds.toString();
    block.rest.text = formatDurationSeconds(source.restAfterSeconds);
    block.cap.text = formatDurationSeconds(source.timeCapSeconds ?? 600);
    for (final exercise in block.exercises) {
      exercise.dispose();
    }
    block.exercises
      ..clear()
      ..addAll(source.items.map(_Exercise.fromItem));
    return block;
  }

  final name = TextEditingController(text: 'Fuerza');
  final rounds = TextEditingController(text: '3');
  final rest = TextEditingController(text: '01:00');
  final cap = TextEditingController(text: '10:00');
  final exercises = <_Exercise>[_Exercise()];
  WorkoutBlockFormat format = WorkoutBlockFormat.straightSets;

  void dispose() {
    name.dispose();
    rounds.dispose();
    rest.dispose();
    cap.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
  }
}

class _Exercise {
  _Exercise({this.automaticSlot = false});

  _Exercise clone({bool preserveAutomaticSlot = false}) {
    final copy =
        _Exercise(automaticSlot: preserveAutomaticSlot && automaticSlot)
          ..exerciseId = exerciseId
          ..type = type
          ..customSets = customSets;
    copy.count.text = count.text;
    copy.target.text = target.text;
    copy.amrapRepetitions.text = amrapRepetitions.text;
    copy.amrapRir.text = amrapRir.text;
    copy.rest.text = rest.text;
    copy.load.text = load.text;
    copy.rir.text = rir.text;
    for (final entry in variations.entries) {
      copy.variations[entry.key] = _SetVariation()
        ..target.text = entry.value.target.text
        ..rest.text = entry.value.rest.text
        ..load.text = entry.value.load.text
        ..rir.text = entry.value.rir.text;
    }
    return copy;
  }

  final bool automaticSlot;

  bool get isEmptyFormatSlot =>
      automaticSlot &&
      exerciseId == null &&
      type == WorkoutTargetType.repetitions &&
      !customSets &&
      count.text == '3' &&
      target.text.trim().isEmpty &&
      amrapRepetitions.text.trim().isEmpty &&
      rest.text == '60' &&
      load.text.trim().isEmpty &&
      rir.text.trim().isEmpty &&
      amrapRir.text.trim().isEmpty &&
      !variations.values.any((variation) => variation.hasValues);

  factory _Exercise.fromItem(WorkoutItem source) {
    final exercise = _Exercise()..exerciseId = source.exerciseId;
    if (source.sets.isEmpty) return exercise;
    final first = source.sets.first;
    exercise.count.text = source.sets.length.toString();
    exercise.type = first.targetDurationSeconds != null
        ? WorkoutTargetType.duration
        : first.targetDistanceMeters != null
        ? WorkoutTargetType.distance
        : WorkoutTargetType.repetitions;
    String targetText(WorkoutSet set) => switch (exercise.type) {
      WorkoutTargetType.duration => '${set.targetDurationSeconds ?? 0}',
      WorkoutTargetType.distance => _number(set.targetDistanceMeters ?? 0),
      _ => '${set.targetReps ?? 0}',
    };
    exercise.target.text = targetText(first);
    exercise.rest.text = first.restAfterSeconds.toString();
    final commonLoad = source.sets.any((s) => s.targetLoadKg == null)
        ? null
        : first.targetLoadKg;
    final commonRir = source.sets.any((s) => s.targetRir == null)
        ? null
        : first.targetRir;
    exercise.load.text = commonLoad?.toString() ?? '';
    exercise.rir.text = commonRir?.toString() ?? '';
    for (var index = 0; index < source.sets.length; index++) {
      final set = source.sets[index];
      if (targetText(set) != exercise.target.text ||
          set.restAfterSeconds != first.restAfterSeconds ||
          set.targetLoadKg != commonLoad ||
          set.targetRir != commonRir) {
        exercise.customSets = true;
        final variation = exercise.variations.putIfAbsent(
          index,
          _SetVariation.new,
        );
        variation.target.text = targetText(set);
        variation.rest.text = set.restAfterSeconds.toString();
        variation.load.text = set.targetLoadKg?.toString() ?? '';
        variation.rir.text = set.targetRir?.toString() ?? '';
      }
    }
    return exercise;
  }

  final count = TextEditingController(text: '3');
  final target = TextEditingController();
  // Al imponer AMRAP no se reinterpretan segundos o metros como repeticiones,
  // ni se reutiliza esfuerzo histórico incompatible con la tarea anterior.
  final amrapRepetitions = TextEditingController();
  final amrapRir = TextEditingController();
  bool _usesAmrapInputs(WorkoutBlockFormat format) =>
      format == WorkoutBlockFormat.amrap &&
      type != WorkoutTargetType.repetitions;
  TextEditingController targetFor(WorkoutBlockFormat format) =>
      _usesAmrapInputs(format) ? amrapRepetitions : target;
  TextEditingController rirFor(WorkoutBlockFormat format) =>
      _usesAmrapInputs(format) ? amrapRir : rir;
  final rest = TextEditingController(text: '60');
  final load = TextEditingController();
  final rir = TextEditingController();
  String? exerciseId;
  WorkoutTargetType type = WorkoutTargetType.repetitions;
  bool customSets = false;
  final variations = <int, _SetVariation>{};

  void dispose() {
    count.dispose();
    target.dispose();
    amrapRepetitions.dispose();
    amrapRir.dispose();
    rest.dispose();
    load.dispose();
    rir.dispose();
    for (final variation in variations.values) {
      variation.dispose();
    }
  }
}

String _time(int seconds) => formatDurationSeconds(seconds);

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

class _SetVariation {
  final target = TextEditingController();
  final rest = TextEditingController();
  final load = TextEditingController();
  final rir = TextEditingController();

  bool get hasValues =>
      [target, rest, load, rir].any((controller) => controller.text.isNotEmpty);

  void dispose() {
    target.dispose();
    rest.dispose();
    load.dispose();
    rir.dispose();
  }
}
