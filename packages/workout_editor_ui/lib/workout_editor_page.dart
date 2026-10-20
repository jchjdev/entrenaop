import 'package:workout_editor_ui/duration_input_formatter.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_core/running_workout_estimator.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/running_step_fields.dart';
import 'package:workout_editor_ui/workout_format_field.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/compact_field_layout.dart';

import 'workout_editor_exercise.dart';

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
  });

  final Future<List<WorkoutEditorExercise>> Function() loadExercises;
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

class _WorkoutEditorPageState extends State<WorkoutEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _segments = <_Segment>[_Segment()];
  final _blocks = <_StrengthBlock>[_StrengthBlock()];
  List<WorkoutEditorExercise> _catalog = const [];
  bool _running = true;
  bool _busy = false;
  String? _error;
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
    if (widget.originalTemplate case final original?) _populate(original);
    if (widget.warmup) {
      _running = false;
      for (final block in _blocks) {
        block.format = WorkoutBlockFormat.straightSets;
      }
    }
    _savedStamp = _draftStamp;
    widget
        .loadExercises()
        .then((items) {
          if (mounted) setState(() => _catalog = items);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() => _error = 'No se pudo cargar el catálogo.');
          }
        });
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
    if (_running) {
      final sets = <WorkoutSetDraft>[];
      for (final segment in _segments) {
        final count = int.tryParse(segment.count.text);
        final target = segment.byDistance
            ? double.tryParse(segment.target.text.replaceAll(',', '.'))
            : _clock(segment.target.text)?.toDouble();
        final pace = segment.pace.text.trim().isEmpty
            ? null
            : _pace(segment.pace.text);
        final paceMax = segment.paceMax.text.trim().isEmpty
            ? pace
            : _pace(segment.paceMax.text);
        final recovery = segment.recovery == null
            ? null
            : segment.recoveryByDistance
            ? double.tryParse(segment.recoveryTime.text.replaceAll(',', '.'))
            : _clock(segment.recoveryTime.text)?.toDouble();
        if (count == null ||
            count < 1 ||
            count > 40 ||
            target == null ||
            target <= 0 ||
            (segment.pace.text.trim().isNotEmpty && pace == null) ||
            (segment.paceMax.text.trim().isNotEmpty &&
                (pace == null || paceMax == null)) ||
            (segment.recovery != null && (recovery == null || recovery <= 0))) {
          throw const FormatException(
            'Revisa repeticiones, objetivo, ritmo y recuperación de los tramos.',
          );
        }
        final set = WorkoutSetDraft(
          targetType: segment.byDistance
              ? WorkoutTargetType.distance
              : WorkoutTargetType.duration,
          targetValue: target,
          restAfterSeconds: 0,
          targetPaceMinSecondsPerKm: pace,
          targetPaceMaxSecondsPerKm: paceMax,
          recoveryType: segment.recovery,
          recoveryDurationSeconds: segment.recoveryByDistance
              ? null
              : recovery?.round(),
          recoveryDistanceMeters: segment.recoveryByDistance ? recovery : null,
        );
        sets.addAll(List.filled(count, set));
      }
      final estimate = estimateRunningWorkout(sets);
      return CreatePersonalWorkoutInput(
        name: _name.text.trim(),
        description: _description.text.trim(),
        estimatedDurationMinutes: estimate.isComplete
            ? estimate.estimatedMinutes
            : null,
        blocks: [
          WorkoutBlockDraft(
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            exercises: [
              WorkoutExerciseDraft(exerciseId: runningExerciseId, sets: sets),
            ],
          ),
        ],
      );
    }
    final blocks = <WorkoutBlockDraft>[];
    for (final block in _blocks) {
      final format = block.format;
      final usesRounds =
          format == WorkoutBlockFormat.superset ||
          format == WorkoutBlockFormat.circuit ||
          format == WorkoutBlockFormat.intervals ||
          format == WorkoutBlockFormat.emom;
      final rounds = format == WorkoutBlockFormat.tabata
          ? 8
          : usesRounds
          ? int.tryParse(block.rounds.text.trim())
          : 1;
      final blockRest = format == WorkoutBlockFormat.tabata
          ? 10
          : format == WorkoutBlockFormat.emom
          ? 60
          : usesRounds
          ? _clock(block.rest.text.trim())
          : 0;
      final cap = format == WorkoutBlockFormat.amrap
          ? _clock(block.cap.text)
          : null;
      if (rounds == null ||
          rounds < 1 ||
          rounds > 20 ||
          blockRest == null ||
          (format == WorkoutBlockFormat.amrap && cap == null)) {
        throw const FormatException(
          'Revisa rondas, descanso y límite del bloque.',
        );
      }

      final exercises = <WorkoutExerciseDraft>[];
      for (final item in block.exercises) {
        if (item.exerciseId == null) {
          throw const FormatException(
            'Selecciona un ejercicio en cada posición.',
          );
        }
        final type = format == WorkoutBlockFormat.tabata
            ? WorkoutTargetType.duration
            : format == WorkoutBlockFormat.amrap
            ? WorkoutTargetType.repetitions
            : item.type;
        final targetInput = item.targetFor(format);
        final rirInput = item.rirFor(format);
        final target = format == WorkoutBlockFormat.tabata
            ? 20.0
            : type == WorkoutTargetType.duration
            ? int.tryParse(targetInput.text.trim())?.toDouble()
            : double.tryParse(targetInput.text.replaceAll(',', '.'));
        final count = format == WorkoutBlockFormat.straightSets
            ? int.tryParse(item.count.text)
            : usesRounds
            ? rounds
            : 1;
        final rest =
            format == WorkoutBlockFormat.tabata ||
                format == WorkoutBlockFormat.amrap ||
                format == WorkoutBlockFormat.emom ||
                format == WorkoutBlockFormat.intervals
            ? 0
            : int.tryParse(item.rest.text.trim());
        final load =
            format == WorkoutBlockFormat.tabata || item.load.text.trim().isEmpty
            ? null
            : double.tryParse(item.load.text.replaceAll(',', '.'));
        final rir =
            format == WorkoutBlockFormat.tabata || rirInput.text.trim().isEmpty
            ? null
            : double.tryParse(rirInput.text.replaceAll(',', '.'));
        if (target == null ||
            target <= 0 ||
            count == null ||
            count < 1 ||
            count > 20 ||
            rest == null ||
            (format != WorkoutBlockFormat.tabata &&
                item.load.text.trim().isNotEmpty &&
                load == null) ||
            (format != WorkoutBlockFormat.tabata &&
                rirInput.text.trim().isNotEmpty &&
                rir == null)) {
          throw const FormatException(
            'Revisa las series, objetivos, descansos y cargas.',
          );
        }
        final sets = <WorkoutSetDraft>[];
        for (var setIndex = 0; setIndex < count; setIndex++) {
          // Tabata tiene dosis fija y AMRAP un objetivo común. Las excepciones
          // ocultas se conservan en el editor, pero no contaminan su receta.
          final variation =
              item.customSets &&
                  format != WorkoutBlockFormat.tabata &&
                  format != WorkoutBlockFormat.amrap
              ? item.variations.putIfAbsent(setIndex, _SetVariation.new)
              : null;
          final targetText = variation?.target.text.trim() ?? '';
          final setTarget = targetText.isEmpty
              ? target
              : type == WorkoutTargetType.duration
              ? int.tryParse(targetText)?.toDouble()
              : double.tryParse(targetText.replaceAll(',', '.'));
          final restText = variation?.rest.text.trim() ?? '';
          final setRest =
              format != WorkoutBlockFormat.straightSets || restText.isEmpty
              ? rest
              : int.tryParse(restText);
          final loadText = variation?.load.text.trim() ?? '';
          final setLoad = loadText.isEmpty
              ? load
              : double.tryParse(loadText.replaceAll(',', '.'));
          final rirText = variation?.rir.text.trim() ?? '';
          final setRir = rirText.isEmpty
              ? rir
              : double.tryParse(rirText.replaceAll(',', '.'));
          if (setTarget == null ||
              setTarget <= 0 ||
              setRest == null ||
              (loadText.isNotEmpty && setLoad == null) ||
              (rirText.isNotEmpty && setRir == null)) {
            throw FormatException(
              'Revisa la serie ${setIndex + 1} del ejercicio.',
            );
          }
          sets.add(
            WorkoutSetDraft(
              targetType: type,
              targetValue: setTarget,
              restAfterSeconds: setRest,
              targetLoadKg: setLoad,
              targetRir: setRir,
            ),
          );
        }
        exercises.add(
          WorkoutExerciseDraft(exerciseId: item.exerciseId!, sets: sets),
        );
      }
      blocks.add(
        WorkoutBlockDraft(
          name: block.name.text.trim(),
          format: format,
          rounds: rounds,
          restAfterSeconds: blockRest,
          timeCapSeconds: cap,
          exercises: exercises,
        ),
      );
    }
    final duration = _duration.text.trim().isEmpty
        ? null
        : int.tryParse(_duration.text.trim());
    if (_duration.text.trim().isNotEmpty && duration == null) {
      throw const FormatException(
        'La duración estimada debe estar en minutos.',
      );
    }
    return CreatePersonalWorkoutInput(
      name: _name.text.trim(),
      description: _description.text.trim(),
      estimatedDurationMinutes: duration,
      blocks: blocks,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    try {
      final input = _input();
      validateWorkoutDraft(input);
      setState(() {
        _busy = true;
        _error = null;
      });
      final savedId = await widget.onSave(input);
      if (mounted) {
        setState(() {
          _busy = false;
          _savedStamp = _draftStamp;
        });
        widget.onSaved(savedId);
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = widget.saveErrorMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _runningEstimate() {
    if (!_running ||
        _segments.any((segment) => segment.target.text.trim().isEmpty)) {
      return null;
    }
    try {
      final input = _input();
      return input.estimatedDurationMinutes == null
          ? 'Completa los ritmos para calcular la duración.'
          : 'Duración estimada: ${input.estimatedDurationMinutes} min';
    } on FormatException {
      return null;
    }
  }

  void _moveSegment(int index, int offset) {
    setState(() {
      final segment = _segments.removeAt(index);
      _segments.insert(index + offset, segment);
    });
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
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _draftStamp != _savedStamp,
    isBusy: () => _busy,
    child: AbsorbPointer(absorbing: _busy, child: _buildPage(context)),
  );

  Widget _buildPage(BuildContext context) => widget.embedded
      ? _editorContent()
      : Scaffold(
          appBar: AppBar(
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
          body: _editorContent(),
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
      TextField(
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
      if (!widget.warmup)
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
      if (_error != null) ...[
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
            : ListView(padding: const EdgeInsets.all(24), children: children),
      ),
    );
  }

  Widget _runningEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Tramos de carrera', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Las series iguales se muestran juntas, pero se guardan como parciales individuales para registrar resultados.',
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _segments.length; i++)
        Card(
          key: ValueKey(_segments[i]),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rowTitle(
                  'Tramo ${i + 1}',
                  _segments.length > 1
                      ? () => setState(() => _segments.removeAt(i).dispose())
                      : null,
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Subir tramo',
                      onPressed: i == 0 ? null : () => _moveSegment(i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Bajar tramo',
                      onPressed: i == _segments.length - 1
                          ? null
                          : () => _moveSegment(i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
                _field(
                  _segments[i].count,
                  'Veces',
                  100,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                RunningStepFields(
                  adminLabels: true,
                  targetType: _segments[i].byDistance
                      ? WorkoutTargetType.distance
                      : WorkoutTargetType.duration,
                  targetController: _segments[i].target,
                  paceMinController: _segments[i].pace,
                  paceMaxController: _segments[i].paceMax,
                  recoveryType: _segments[i].recovery,
                  recoveryByDistance: _segments[i].recoveryByDistance,
                  recoveryController: _segments[i].recoveryTime,
                  onEdited: () => setState(() {}),
                  onTargetTypeChanged: (value) => setState(() {
                    _segments[i].byDistance =
                        value == WorkoutTargetType.distance;
                    _segments[i].target.text = _segments[i].byDistance
                        ? '1000'
                        : '20:00';
                  }),
                  onRecoveryTypeChanged: (value) => setState(() {
                    _segments[i].recovery = value;
                    if (value == RunningRecoveryType.passive) {
                      _segments[i].recoveryByDistance = false;
                      _segments[i].recoveryTime.text = '01:00';
                    } else if (value != null &&
                        _segments[i].recoveryTime.text.isEmpty) {
                      _segments[i].recoveryTime.text = '01:00';
                    }
                  }),
                  onRecoveryMeasureChanged: (value) => setState(() {
                    _segments[i].recoveryByDistance = value;
                    _segments[i].recoveryTime.text = value ? '200' : '1:00';
                  }),
                ),
              ],
            ),
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _segments.add(_Segment())),
            icon: const Icon(Icons.add),
            label: const Text('Añadir tramo distinto'),
          ),
          TextButton.icon(
            onPressed: _addPyramid,
            icon: const Icon(Icons.stacked_line_chart),
            label: const Text('Crear pirámide'),
          ),
        ],
      ),
      if (_runningEstimate() case final estimate?)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(estimate)),
    ],
  );

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
                  tabata ? 'Intervalo ${index + 1}' : 'Posición ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
            onPressed: _catalog.isEmpty
                ? null
                : () async {
                    final selected = await _chooseExercise();
                    if (selected != null && mounted) {
                      setState(() => item.exerciseId = selected.id);
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

  Future<WorkoutEditorExercise?> _chooseExercise() {
    return showDialog<WorkoutEditorExercise>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buscar ejercicio'),
        content: SizedBox(
          width: 480,
          height: 430,
          child: ExerciseSearchList<WorkoutEditorExercise>(
            exercises: _catalog,
            nameOf: (exercise) => exercise.name,
            searchTermsOf: (exercise) => [
              exercise.name,
              ...exercise.muscleGroups,
              ...exercise.equipment,
            ],
            thumbnailOf: (exercise) => exercise.thumbnailUrl,
            subtitleOf: (exercise) =>
                [...exercise.muscleGroups, ...exercise.equipment].join(' · '),
            onSelected: (exercise) => Navigator.of(dialogContext).pop(exercise),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
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

  Widget _rowTitle(String title, VoidCallback? remove) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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

  factory _Segment.fromSet(WorkoutSet set) {
    final segment = _Segment();
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
    segment.recovery = set.recoveryType;
    segment.recoveryByDistance = set.recoveryDistanceMeters != null;
    segment.recoveryTime.text = set.recoveryDistanceMeters != null
        ? _number(set.recoveryDistanceMeters!)
        : _time(set.recoveryDurationSeconds ?? 60);
    return segment;
  }

  bool matches(WorkoutSet set) =>
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
    exercise.load.text = first.targetLoadKg?.toString() ?? '';
    exercise.rir.text = first.targetRir?.toString() ?? '';
    for (var index = 1; index < source.sets.length; index++) {
      final set = source.sets[index];
      if (targetText(set) != exercise.target.text ||
          set.restAfterSeconds != first.restAfterSeconds ||
          set.targetLoadKg != first.targetLoadKg ||
          set.targetRir != first.targetRir) {
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

int? _clock(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null ||
      seconds == null ||
      minutes < 0 ||
      seconds < 0 ||
      seconds > 59) {
    return null;
  }
  return minutes * 60 + seconds;
}

int? _pace(String value) {
  final trimmed = value.trim();
  if (trimmed.contains(':')) return _clock(trimmed);
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return null;
  if (trimmed.length <= 2) return int.parse(trimmed) * 60;
  final minutes = int.tryParse(trimmed.substring(0, trimmed.length - 2));
  final seconds = int.tryParse(trimmed.substring(trimmed.length - 2));
  if (minutes == null || seconds == null || seconds > 59) return null;
  return minutes * 60 + seconds;
}
