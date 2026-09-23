import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workout_core/running_workout_estimator.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/exercise_search_list.dart';
import 'package:workout_editor_ui/running_step_fields.dart';
import 'package:workout_editor_ui/workout_format_field.dart';

class AdminWorkoutEditorPage extends StatefulWidget {
  const AdminWorkoutEditorPage({
    super.key,
    required this.program,
    required this.repository,
    this.originalTemplate,
    this.revisionId,
  });

  final AdminProgram? program;
  final AdminWorkoutRepository repository;
  final WorkoutTemplate? originalTemplate;
  final String? revisionId;

  @override
  State<AdminWorkoutEditorPage> createState() => _AdminWorkoutEditorPageState();
}

class _AdminWorkoutEditorPageState extends State<AdminWorkoutEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _segments = <_Segment>[_Segment()];
  final _blocks = <_StrengthBlock>[_StrengthBlock()];
  List<AdminExercise> _catalog = const [];
  bool _running = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.originalTemplate case final original?) _populate(original);
    widget.repository
        .listPublicExercises()
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
          ? _clock(block.rest.text)
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
        final target = format == WorkoutBlockFormat.tabata
            ? 20.0
            : type == WorkoutTargetType.duration
            ? _clock(item.target.text)?.toDouble()
            : double.tryParse(item.target.text.replaceAll(',', '.'));
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
            : _clock(item.rest.text);
        final load =
            format == WorkoutBlockFormat.tabata || item.load.text.trim().isEmpty
            ? null
            : double.tryParse(item.load.text.replaceAll(',', '.'));
        final rir =
            format == WorkoutBlockFormat.tabata || item.rir.text.trim().isEmpty
            ? null
            : double.tryParse(item.rir.text.replaceAll(',', '.'));
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
                item.rir.text.trim().isNotEmpty &&
                rir == null)) {
          throw const FormatException(
            'Revisa las series, objetivos, descansos y cargas.',
          );
        }
        final sets = <WorkoutSetDraft>[];
        for (var setIndex = 0; setIndex < count; setIndex++) {
          final variation = item.customSets
              ? item.variations.putIfAbsent(setIndex, _SetVariation.new)
              : null;
          final targetText = variation?.target.text.trim() ?? '';
          final setTarget = targetText.isEmpty
              ? target
              : type == WorkoutTargetType.duration
              ? _clock(targetText)?.toDouble()
              : double.tryParse(targetText.replaceAll(',', '.'));
          final restText = variation?.rest.text.trim() ?? '';
          final setRest =
              format != WorkoutBlockFormat.straightSets || restText.isEmpty
              ? rest
              : _clock(restText);
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
    try {
      final input = _input();
      validateWorkoutDraft(input);
      setState(() {
        _busy = true;
        _error = null;
      });
      if (widget.revisionId case final id?) {
        await widget.repository.revise(id, input);
      } else {
        await widget.repository.createDraft(widget.program?.id, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar el borrador. Revisa permisos y conexión.',
        );
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.revisionId == null ? 'Nueva sesión' : 'Revisar sesión'} · ${widget.program?.name ?? 'EntrenaOP'}',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.program == null
                  ? 'Sesión general en borrador'
                  : 'Sesión del programa en borrador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.program == null
                  ? 'Se guarda en la biblioteca general. No será visible hasta que la publiques.'
                  : 'Se vincula al programa, no a la biblioteca general. Publicar no la asigna a ningún alumno.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre de la sesión',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Indicaciones (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Carrera')),
                ButtonSegment(value: false, label: Text('Fuerza convencional')),
              ],
              selected: {_running},
              onSelectionChanged: (selection) =>
                  setState(() => _running = selection.first),
            ),
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
                label: Text(
                  _busy
                      ? 'Guardando…'
                      : widget.revisionId == null
                      ? 'Guardar borrador'
                      : 'Guardar revisión como borrador',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

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
                      _segments[i].recoveryTime.text = '1:00';
                    } else if (value != null &&
                        _segments[i].recoveryTime.text.isEmpty) {
                      _segments[i].recoveryTime.text = '1:00';
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
        'Combina bloques convencionales, superseries, circuitos, intervalos, EMOM, AMRAP o Tabata.',
      ),
      const SizedBox(height: 12),
      if (_catalog.isEmpty) const Text('No hay ejercicios públicos cargados.'),
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
          children: [
            _field(block.name, 'Nombre del bloque', 230),
            SizedBox(
              width: 265,
              child: WorkoutFormatField(
                format: format,
                exerciseCount: block.exercises.length,
                label: 'Formato',
                onChanged: (value) {
                  setState(() {
                    block.format = value;
                    final minimum = value == WorkoutBlockFormat.tabata
                        ? 8
                        : value == WorkoutBlockFormat.superset ||
                              value == WorkoutBlockFormat.circuit
                        ? 2
                        : 1;
                    while (block.exercises.length < minimum) {
                      block.exercises.add(_Exercise());
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
    final canRemove = tabata
        ? block.exercises.length > 8
        : block.exercises.length > 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tabata ? 'Intervalo ${index + 1}' : 'Posición ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
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
                  : _catalog
                            .where((exercise) => exercise.id == item.exerciseId)
                            .map((exercise) => exercise.name)
                            .firstOrNull ??
                        'Buscar ejercicio del catálogo',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 12,
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
                  child: DropdownButtonFormField<WorkoutTargetType>(
                    key: ValueKey(item.type),
                    initialValue: item.type,
                    decoration: const InputDecoration(labelText: 'Objetivo'),
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
              if (tabata)
                const Padding(
                  padding: EdgeInsets.only(top: 15),
                  child: Text('20 s de trabajo · 10 s de recuperación'),
                )
              else
                _field(
                  item.target,
                  item.type == WorkoutTargetType.duration && !amrap
                      ? 'Tiempo (m:ss)'
                      : 'Cantidad',
                  145,
                ),
              if (!tabata &&
                  !amrap &&
                  format != WorkoutBlockFormat.emom &&
                  format != WorkoutBlockFormat.intervals)
                _field(item.rest, 'Descanso (m:ss)', 165),
              if (!tabata) _field(item.load, 'Carga kg (opcional)', 160),
              if (!tabata) _field(item.rir, 'RIR (opcional)', 140),
            ],
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
            if (item.customSets)
              for (
                var setIndex = 0;
                setIndex <
                    (fixedRounds
                            ? int.tryParse(block.rounds.text) ?? 0
                            : int.tryParse(item.count.text) ?? 0)
                        .clamp(0, 20);
                setIndex++
              )
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Serie ${setIndex + 1}'),
                      _field(
                        item.variations
                            .putIfAbsent(setIndex, _SetVariation.new)
                            .target,
                        'Objetivo propio',
                        135,
                      ),
                      if (!fixedRounds)
                        _field(
                          item.variations[setIndex]!.rest,
                          'Descanso propio (m:ss)',
                          175,
                        ),
                      _field(
                        item.variations[setIndex]!.load,
                        'Carga propia kg',
                        135,
                      ),
                      _field(item.variations[setIndex]!.rir, 'RIR propio', 110),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Future<AdminExercise?> _chooseExercise() {
    return showDialog<AdminExercise>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buscar ejercicio'),
        content: SizedBox(
          width: 480,
          height: 430,
          child: ExerciseSearchList<AdminExercise>(
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
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const Spacer(),
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
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: clock || text
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: clock
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))]
            : null,
        decoration: InputDecoration(labelText: label),
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
  final recoveryTime = TextEditingController(text: '1:00');
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
    block.rest.text = _time(source.restAfterSeconds);
    block.cap.text = _time(source.timeCapSeconds ?? 600);
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
  final rest = TextEditingController(text: '1:00');
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
  _Exercise();

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
      WorkoutTargetType.duration => _time(set.targetDurationSeconds ?? 0),
      WorkoutTargetType.distance => _number(set.targetDistanceMeters ?? 0),
      _ => '${set.targetReps ?? 0}',
    };
    exercise.target.text = targetText(first);
    exercise.rest.text = _time(first.restAfterSeconds);
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
        variation.rest.text = _time(set.restAfterSeconds);
        variation.load.text = set.targetLoadKg?.toString() ?? '';
        variation.rir.text = set.targetRir?.toString() ?? '';
      }
    }
    return exercise;
  }

  final count = TextEditingController(text: '3');
  final target = TextEditingController();
  final rest = TextEditingController(text: '1:00');
  final load = TextEditingController();
  final rir = TextEditingController();
  String? exerciseId;
  WorkoutTargetType type = WorkoutTargetType.repetitions;
  bool customSets = false;
  final variations = <int, _SetVariation>{};

  void dispose() {
    count.dispose();
    target.dispose();
    rest.dispose();
    load.dispose();
    rir.dispose();
    for (final variation in variations.values) {
      variation.dispose();
    }
  }
}

String _time(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

class _SetVariation {
  final target = TextEditingController();
  final rest = TextEditingController();
  final load = TextEditingController();
  final rir = TextEditingController();

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
