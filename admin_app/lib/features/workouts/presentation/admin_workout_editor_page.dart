import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/running_workout_estimator.dart';
import 'package:workout_core/workout_draft_validator.dart';
import 'package:workout_core/workout_template.dart';

class AdminWorkoutEditorPage extends StatefulWidget {
  const AdminWorkoutEditorPage({
    super.key,
    required this.program,
    required this.repository,
  });

  final AdminProgram program;
  final AdminWorkoutRepository repository;

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
        final set = WorkoutSetDraft(
          targetType: type,
          targetValue: target,
          restAfterSeconds: rest,
          targetLoadKg: load,
          targetRir: rir,
        );
        exercises.add(
          WorkoutExerciseDraft(
            exerciseId: item.exerciseId!,
            sets: List.filled(count, set),
          ),
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
      await widget.repository.createDraft(widget.program.id, input);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Nueva sesión · ${widget.program.name}')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sesión oficial en borrador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Se vincula al programa, pero no aparece al alumno ni en su agenda. Publicar y asignar son pasos posteriores.',
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
                label: Text(_busy ? 'Guardando…' : 'Guardar borrador'),
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
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    _field(_segments[i].count, 'Veces', 100),
                    SizedBox(
                      width: 155,
                      child: SwitchListTile(
                        title: const Text('Metros'),
                        value: _segments[i].byDistance,
                        onChanged: (value) =>
                            setState(() => _segments[i].byDistance = value),
                      ),
                    ),
                    _field(
                      _segments[i].target,
                      _segments[i].byDistance
                          ? 'Distancia (m)'
                          : 'Tiempo (m:ss)',
                      155,
                    ),
                    _field(_segments[i].pace, 'Ritmo (m:ss/km)', 155),
                    _field(_segments[i].paceMax, 'Hasta (m:ss/km)', 155),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<RunningRecoveryType?>(
                        initialValue: _segments[i].recovery,
                        decoration: const InputDecoration(
                          labelText: 'Recuperación',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Ninguna')),
                          DropdownMenuItem(
                            value: RunningRecoveryType.passive,
                            child: Text('Pasiva'),
                          ),
                          DropdownMenuItem(
                            value: RunningRecoveryType.walking,
                            child: Text('Andando'),
                          ),
                          DropdownMenuItem(
                            value: RunningRecoveryType.jogging,
                            child: Text('Trote'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _segments[i].recovery = value;
                          if (value == RunningRecoveryType.passive) {
                            _segments[i].recoveryByDistance = false;
                          }
                        }),
                      ),
                    ),
                    if (_segments[i].recovery != null &&
                        _segments[i].recovery != RunningRecoveryType.passive)
                      SizedBox(
                        width: 165,
                        child: SwitchListTile(
                          title: const Text('Rec. metros'),
                          value: _segments[i].recoveryByDistance,
                          onChanged: (value) => setState(
                            () => _segments[i].recoveryByDistance = value,
                          ),
                        ),
                      ),
                    if (_segments[i].recovery != null)
                      _field(
                        _segments[i].recoveryTime,
                        _segments[i].recoveryByDistance
                            ? 'Recuperación (m)'
                            : 'Recuperación (m:ss)',
                        180,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      TextButton.icon(
        onPressed: () => setState(() => _segments.add(_Segment())),
        icon: const Icon(Icons.add),
        label: const Text('Añadir tramo distinto'),
      ),
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
              child: DropdownButtonFormField<WorkoutBlockFormat>(
                isExpanded: true,
                key: ValueKey(format),
                initialValue: format,
                decoration: const InputDecoration(labelText: 'Formato'),
                items: const [
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.straightSets,
                    child: Text('Series convencionales'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.superset,
                    child: Text('Superserie'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.circuit,
                    child: Text('Circuito'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.intervals,
                    child: Text('Intervalos'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.emom,
                    child: Text('EMOM'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.amrap,
                    child: Text('AMRAP'),
                  ),
                  DropdownMenuItem(
                    value: WorkoutBlockFormat.tabata,
                    child: Text('Tabata 20/10'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
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
            if (usesRounds) _field(block.rounds, 'Rondas', 100),
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
          DropdownButtonFormField<String>(
            key: ValueKey(item.exerciseId),
            initialValue: item.exerciseId,
            decoration: const InputDecoration(
              labelText: 'Ejercicio del catálogo',
            ),
            items: [
              for (final exercise in _catalog)
                DropdownMenuItem(
                  value: exercise.id,
                  child: Text(exercise.name),
                ),
            ],
            onChanged: (value) => item.exerciseId = value,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              if (!fixedRounds) _field(item.count, 'Series', 100),
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

  Widget _field(TextEditingController controller, String label, double width) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _Segment {
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
  final count = TextEditingController(text: '3');
  final target = TextEditingController();
  final rest = TextEditingController(text: '1:00');
  final load = TextEditingController();
  final rir = TextEditingController();
  String? exerciseId;
  WorkoutTargetType type = WorkoutTargetType.repetitions;

  void dispose() {
    count.dispose();
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
