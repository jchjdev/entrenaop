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
  final _exercises = <_Exercise>[_Exercise()];
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
    for (final exercise in _exercises) {
      exercise.dispose();
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
        final recovery = segment.recovery == null
            ? null
            : _clock(segment.recoveryTime.text);
        if (count == null ||
            count < 1 ||
            count > 40 ||
            target == null ||
            target <= 0 ||
            (segment.pace.text.trim().isNotEmpty && pace == null) ||
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
          targetPaceMaxSecondsPerKm: pace,
          recoveryType: segment.recovery,
          recoveryDurationSeconds: recovery,
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
    final exercises = <WorkoutExerciseDraft>[];
    for (final item in _exercises) {
      final count = int.tryParse(item.count.text);
      final target = item.type == WorkoutTargetType.duration
          ? _clock(item.target.text)?.toDouble()
          : double.tryParse(item.target.text.replaceAll(',', '.'));
      final rest = _clock(item.rest.text);
      if (item.exerciseId == null ||
          count == null ||
          count < 1 ||
          count > 20 ||
          target == null ||
          target <= 0 ||
          rest == null) {
        throw const FormatException(
          'Revisa ejercicio, series, objetivo y descanso.',
        );
      }
      final set = WorkoutSetDraft(
        targetType: item.type,
        targetValue: target,
        restAfterSeconds: rest,
      );
      exercises.add(
        WorkoutExerciseDraft(
          exerciseId: item.exerciseId!,
          sets: List.filled(count, set),
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
      blocks: [WorkoutBlockDraft(name: 'Fuerza', exercises: exercises)],
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
                        onChanged: (value) =>
                            setState(() => _segments[i].recovery = value),
                      ),
                    ),
                    if (_segments[i].recovery != null)
                      _field(
                        _segments[i].recoveryTime,
                        'Recuperación (m:ss)',
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
        'Fuerza convencional',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text('Un bloque, con series iguales para cada ejercicio.'),
      const SizedBox(height: 12),
      if (_catalog.isEmpty) const Text('No hay ejercicios públicos cargados.'),
      for (var i = 0; i < _exercises.length; i++)
        Card(
          key: ValueKey(_exercises[i]),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rowTitle(
                  'Ejercicio ${i + 1}',
                  _exercises.length > 1
                      ? () => setState(() => _exercises.removeAt(i).dispose())
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _exercises[i].exerciseId,
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
                  onChanged: (value) => _exercises[i].exerciseId = value,
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    _field(_exercises[i].count, 'Series', 100),
                    SizedBox(
                      width: 225,
                      child: DropdownButtonFormField<WorkoutTargetType>(
                        initialValue: _exercises[i].type,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo',
                        ),
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
                        onChanged: (value) => setState(
                          () =>
                              _exercises[i].type = value ?? _exercises[i].type,
                        ),
                      ),
                    ),
                    _field(
                      _exercises[i].target,
                      _exercises[i].type == WorkoutTargetType.duration
                          ? 'Tiempo (m:ss)'
                          : 'Cantidad',
                      145,
                    ),
                    _field(_exercises[i].rest, 'Descanso (m:ss)', 165),
                  ],
                ),
              ],
            ),
          ),
        ),
      TextButton.icon(
        onPressed: _catalog.isEmpty
            ? null
            : () => setState(() => _exercises.add(_Exercise())),
        icon: const Icon(Icons.add),
        label: const Text('Añadir ejercicio'),
      ),
      _field(_duration, 'Duración estimada (min, opcional)', 265),
    ],
  );

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
  final recoveryTime = TextEditingController(text: '1:00');
  bool byDistance = true;
  RunningRecoveryType? recovery;

  void dispose() {
    count.dispose();
    target.dispose();
    pace.dispose();
    recoveryTime.dispose();
  }
}

class _Exercise {
  final count = TextEditingController(text: '3');
  final target = TextEditingController();
  final rest = TextEditingController(text: '1:00');
  String? exerciseId;
  WorkoutTargetType type = WorkoutTargetType.repetitions;

  void dispose() {
    count.dispose();
    target.dispose();
    rest.dispose();
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
