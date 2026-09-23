import 'dart:async';

import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/running_workout_estimator.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/running_step_fields.dart';

class RunningWorkoutEditorPage extends StatefulWidget {
  const RunningWorkoutEditorPage({super.key});

  @override
  State<RunningWorkoutEditorPage> createState() =>
      _RunningWorkoutEditorPageState();
}

class _RunningWorkoutEditorPageState extends State<RunningWorkoutEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_RunningSegmentData> _segments = [];
  Timer? _autosaveTimer;
  bool _initialized = false;
  bool _allowPop = false;
  bool _suspendAutosave = true;

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    for (final segment in _segments) {
      segment.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutEditorCubit, WorkoutEditorState>(
      listener: (context, state) {
        if (state.status == WorkoutEditorStatus.saved) {
          _autosaveTimer?.cancel();
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.pop(state.createdTemplateId);
          });
        } else if (state.errorMessage case final message?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        _initializeWhenReady(context, state);
        final saving = state.status == WorkoutEditorStatus.saving;
        return PopScope(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !saving) unawaited(_close());
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Volver',
                onPressed: saving ? null : _close,
                icon: const Icon(Icons.close_rounded),
              ),
              title: Text(
                state.originalTemplate == null
                    ? 'Nueva carrera'
                    : 'Editar carrera',
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : _save,
                  child: const Text('Guardar'),
                ),
              ],
            ),
            body: switch (state.status) {
              WorkoutEditorStatus.initial || WorkoutEditorStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              WorkoutEditorStatus.failure => Center(
                child: FilledButton.icon(
                  onPressed: context.read<WorkoutEditorCubit>().load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ),
              _ => _buildForm(state.originalTemplate, saving),
            },
          ),
        );
      },
    );
  }

  void _initializeWhenReady(BuildContext context, WorkoutEditorState state) {
    if (_initialized || state.status != WorkoutEditorStatus.ready) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var source = state.originalTemplate == null
          ? null
          : _inputFromTemplate(state.originalTemplate!);
      if (state.draft case final draft?) {
        final restore = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Borrador encontrado'),
            content: const Text(
              'Hay cambios de esta sesión guardados en este dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Descartar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Recuperar'),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (restore == true) {
          source = draft.input;
        } else {
          await context.read<WorkoutEditorCubit>().discardDraft();
        }
      }
      if (!context.mounted) return;
      _populate(source ?? _emptyInput());
      _suspendAutosave = false;
    });
  }

  Widget _buildForm(WorkoutTemplate? original, bool saving) {
    return Form(
      key: _formKey,
      onChanged: _changed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    original == null
                        ? 'Diseña una carrera'
                        : 'Crea una nueva versión',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrupa las series iguales en un solo tramo. Al entrenar se mostrarán todas en su orden real.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  if (original != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Versión ${original.version} · se guardará como versión ${original.version + 1}',
                      style: const TextStyle(color: Color(0xFFFFB08A)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la sesión',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Escribe al menos 3 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción opcional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RunningEstimateCard(estimate: _safeEstimate()),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tramos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_segments.length} ${_segments.length == 1 ? 'bloque' : 'bloques'} · $_totalSegments/40 tramos',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Una carrera continua usa un tramo. Para series iguales, ajusta sus repeticiones sin duplicar tarjetas.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < _segments.length; index++) ...[
                    _RunningSegmentCard(
                      key: ObjectKey(_segments[index]),
                      index: index,
                      data: _segments[index],
                      canDelete: _segments.length > 1,
                      onChanged: _changed,
                      onMoveUp: index == 0 ? null : () => _move(index, -1),
                      onMoveDown: index == _segments.length - 1
                          ? null
                          : () => _move(index, 1),
                      onDelete: _segments.length == 1
                          ? null
                          : () => _delete(index),
                      onRepetitionsChanged: (repetitions) =>
                          _setRepetitions(index, repetitions),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _totalSegments >= 40 ? null : _addSegment,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Añadir tramo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _segments.isEmpty ? null : _repeatLast,
                        icon: const Icon(Icons.repeat_rounded),
                        label: const Text('Repetir último'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _segments.isEmpty ? null : _addPyramid,
                        icon: const Icon(Icons.stacked_line_chart_rounded),
                        label: const Text('Crear pirámide'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        original == null
                            ? 'Guardar sesión de carrera'
                            : 'Guardar nueva versión',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _populate(CreatePersonalWorkoutInput input) {
    _nameController.text = input.name;
    _descriptionController.text = input.description ?? '';
    final sets = input.blocks.first.exercises.first.sets;
    setState(() {
      for (final segment in _segments) {
        segment.dispose();
      }
      _segments
        ..clear()
        ..addAll(_groupConsecutiveSegments(sets));
    });
  }

  CreatePersonalWorkoutInput _currentInput() {
    final sets = _expandedDrafts();
    final estimate = estimateRunningWorkout(sets);
    return CreatePersonalWorkoutInput(
      name: _nameController.text,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text,
      estimatedDurationMinutes:
          estimate.isComplete && estimate.maximumSeconds > 0
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

  int get _totalSegments =>
      _segments.fold(0, (total, segment) => total + segment.repetitions);

  List<WorkoutSetDraft> _expandedDrafts() => [
    for (final segment in _segments)
      for (var repetition = 0; repetition < segment.repetitions; repetition++)
        segment.toDraft(),
  ];

  RunningWorkoutEstimate? _safeEstimate() {
    try {
      return estimateRunningWorkout(_expandedDrafts());
    } on FormatException {
      return null;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (_suspendAutosave) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) unawaited(_persistValidDraft());
    });
  }

  Future<void> _persistValidDraft() async {
    try {
      await context.read<WorkoutEditorCubit>().persistDraft(_currentInput());
    } on FormatException {
      // Mientras el usuario completa un campo parcial mantenemos el último
      // borrador válido en vez de romper la edición.
    }
  }

  void _addSegment() {
    setState(() => _segments.add(_RunningSegmentData()));
    _scheduleAutosave();
  }

  void _delete(int index) {
    setState(() => _segments.removeAt(index).dispose());
    _scheduleAutosave();
  }

  void _move(int index, int offset) {
    setState(() {
      final segment = _segments.removeAt(index);
      _segments.insert(index + offset, segment);
    });
    _scheduleAutosave();
  }

  void _setRepetitions(int index, int repetitions) {
    final others = _totalSegments - _segments[index].repetitions;
    if (repetitions < 1 || others + repetitions > 40) return;
    setState(() => _segments[index].repetitions = repetitions);
    _scheduleAutosave();
  }

  Future<void> _repeatLast() async {
    var repetitionsText = _segments.last.repetitions.toString();
    final copies = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Repetir último tramo'),
        content: TextFormField(
          initialValue: repetitionsText,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => repetitionsText = value,
          decoration: const InputDecoration(
            labelText: 'Repeticiones totales',
            helperText: 'Se mostrarán agrupadas en una sola tarjeta.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(int.tryParse(repetitionsText)),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (copies == null || copies < 1 || copies > 40) return;
    _setRepetitions(_segments.length - 1, copies);
  }

  Future<void> _addPyramid() async {
    var distancesText = '200, 400, 600, 400, 200';
    final values = await showDialog<List<double>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear pirámide'),
        content: TextFormField(
          initialValue: distancesText,
          autofocus: true,
          onChanged: (value) => distancesText = value,
          decoration: const InputDecoration(
            labelText: 'Distancias en metros',
            helperText: 'Ejemplo: 200, 400, 600, 400, 200',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = distancesText
                  .split(',')
                  .map((value) => double.tryParse(value.trim()))
                  .toList();
              if (parsed.isEmpty ||
                  parsed.any((value) => value == null || value <= 0)) {
                return;
              }
              Navigator.of(dialogContext).pop(parsed.cast<double>());
            },
            child: const Text('Expandir'),
          ),
        ],
      ),
    );
    if (values == null || values.length > 40) return;
    final base = _segments.last.copy();
    setState(() {
      for (final segment in _segments) {
        segment.dispose();
      }
      _segments
        ..clear()
        ..addAll(
          values.map(
            (distance) => base.copy()
              ..targetType = WorkoutTargetType.distance
              ..targetController.text = _number(distance)
              ..repetitions = 1,
          ),
        );
    });
    _scheduleAutosave();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final input = _currentInput();
      await context.read<WorkoutEditorCubit>().save(input);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _close() async {
    _autosaveTimer?.cancel();
    if (!_suspendAutosave) {
      await _persistValidDraft();
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }
}

class _RunningSegmentCard extends StatefulWidget {
  const _RunningSegmentCard({
    super.key,
    required this.index,
    required this.data,
    required this.canDelete,
    required this.onChanged,
    required this.onRepetitionsChanged,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
  });

  final int index;
  final _RunningSegmentData data;
  final bool canDelete;
  final VoidCallback onChanged;
  final ValueChanged<int> onRepetitionsChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;

  @override
  State<_RunningSegmentCard> createState() => _RunningSegmentCardState();
}

class _RunningSegmentCardState extends State<_RunningSegmentCard> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tramo ${widget.index + 1}${data.repetitions > 1 ? ' × ${data.repetitions}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Subir',
                  onPressed: widget.onMoveUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Bajar',
                  onPressed: widget.onMoveDown,
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Repeticiones',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  tooltip: 'Una repetición menos',
                  onPressed: data.repetitions > 1
                      ? () => widget.onRepetitionsChanged(data.repetitions - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '× ${data.repetitions}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Una repetición más',
                  onPressed: () =>
                      widget.onRepetitionsChanged(data.repetitions + 1),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RunningStepFields(
              targetType: data.targetType,
              targetController: data.targetController,
              paceMinController: data.paceMinController,
              paceMaxController: data.paceMaxController,
              recoveryType: data.recoveryType,
              recoveryByDistance: data.recoveryByDistance,
              recoveryController: data.recoveryController,
              onEdited: widget.onChanged,
              targetValidator: (_) {
                try {
                  return data.targetValue > 0 ? null : 'Valor no válido';
                } on FormatException {
                  return 'Valor no válido';
                }
              },
              onTargetTypeChanged: (value) {
                setState(() {
                  data.targetType = value;
                  data.targetController.text =
                      value == WorkoutTargetType.distance ? '1000' : '20:00';
                });
                widget.onChanged();
              },
              onRecoveryTypeChanged: (value) {
                setState(() {
                  data.recoveryType = value;
                  if (value == null) {
                    data.recoveryController.clear();
                  } else if (value == RunningRecoveryType.passive) {
                    data.recoveryByDistance = false;
                    data.recoveryController.text = '1:00';
                  } else if (data.recoveryController.text.isEmpty) {
                    data.recoveryController.text = '1:00';
                  }
                });
                widget.onChanged();
              },
              onRecoveryMeasureChanged: (value) {
                setState(() {
                  data.recoveryByDistance = value;
                  data.recoveryController.text = value ? '200' : '1:00';
                });
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningSegmentData {
  _RunningSegmentData({
    this.targetType = WorkoutTargetType.distance,
    String target = '1000',
    String paceMin = '',
    String paceMax = '',
    this.recoveryType,
    this.recoveryByDistance = false,
    String recovery = '',
    this.repetitions = 1,
  }) : targetController = TextEditingController(text: target),
       paceMinController = TextEditingController(text: paceMin),
       paceMaxController = TextEditingController(text: paceMax),
       recoveryController = TextEditingController(text: recovery);

  factory _RunningSegmentData.fromDraft(WorkoutSetDraft set) =>
      _RunningSegmentData(
        targetType: set.targetType,
        target: set.targetType == WorkoutTargetType.duration
            ? _clock(set.targetValue.round())
            : _number(set.targetValue),
        paceMin: set.targetPaceMinSecondsPerKm == null
            ? ''
            : _clock(set.targetPaceMinSecondsPerKm!),
        paceMax: set.targetPaceMaxSecondsPerKm == null
            ? ''
            : _clock(set.targetPaceMaxSecondsPerKm!),
        recoveryType: set.recoveryType,
        recoveryByDistance: set.recoveryDistanceMeters != null,
        recovery: set.recoveryDurationSeconds != null
            ? _clock(set.recoveryDurationSeconds!)
            : set.recoveryDistanceMeters == null
            ? ''
            : _number(set.recoveryDistanceMeters!),
      );

  WorkoutTargetType targetType;
  final TextEditingController targetController;
  final TextEditingController paceMinController;
  final TextEditingController paceMaxController;
  RunningRecoveryType? recoveryType;
  bool recoveryByDistance;
  final TextEditingController recoveryController;
  int repetitions;

  double get targetValue => targetType == WorkoutTargetType.duration
      ? _parseClock(targetController.text).toDouble()
      : _positiveNumber(targetController.text);

  WorkoutSetDraft toDraft() {
    final paceMin = _optionalClock(paceMinController.text);
    final paceMax = _optionalClock(paceMaxController.text);
    if ((paceMin == null) != (paceMax == null)) {
      throw const FormatException('Completa ambos extremos del ritmo.');
    }
    if (paceMin != null && paceMax! < paceMin) {
      throw const FormatException('El rango de ritmo no es válido.');
    }
    final recoveryValue = recoveryType == null
        ? null
        : recoveryByDistance
        ? _positiveNumber(recoveryController.text)
        : _parseClock(recoveryController.text).toDouble();
    return WorkoutSetDraft(
      targetType: targetType,
      targetValue: targetValue,
      restAfterSeconds: 0,
      targetPaceMinSecondsPerKm: paceMin,
      targetPaceMaxSecondsPerKm: paceMax,
      recoveryType: recoveryType,
      recoveryDurationSeconds: recoveryType != null && !recoveryByDistance
          ? recoveryValue!.round()
          : null,
      recoveryDistanceMeters: recoveryType != null && recoveryByDistance
          ? recoveryValue
          : null,
    );
  }

  _RunningSegmentData copy() => _RunningSegmentData(
    targetType: targetType,
    target: targetController.text,
    paceMin: paceMinController.text,
    paceMax: paceMaxController.text,
    recoveryType: recoveryType,
    recoveryByDistance: recoveryByDistance,
    recovery: recoveryController.text,
    repetitions: repetitions,
  );

  void dispose() {
    targetController.dispose();
    paceMinController.dispose();
    paceMaxController.dispose();
    recoveryController.dispose();
  }
}

class _RunningEstimateCard extends StatelessWidget {
  const _RunningEstimateCard({required this.estimate});

  final RunningWorkoutEstimate? estimate;

  @override
  Widget build(BuildContext context) {
    final value = estimate;
    final hasTime = value != null && value.maximumSeconds > 0;
    final title = !hasTime
        ? 'Completa distancia y ritmo para calcularla'
        : _formatEstimate(value);
    final subtitle = value == null || value.isComplete
        ? 'Se actualiza automáticamente con ritmos, distancias y descansos.'
        : 'Estimación parcial: falta ritmo en alguna distancia o recuperación.';
    return Card(
      color: const Color(0xFF171717),
      child: ListTile(
        leading: const Icon(Icons.schedule_rounded),
        title: const Text('Duración estimada'),
        subtitle: Text('$title\n$subtitle'),
        isThreeLine: true,
      ),
    );
  }
}

List<_RunningSegmentData> _groupConsecutiveSegments(
  Iterable<WorkoutSetDraft> sets,
) {
  final groups = <_RunningSegmentData>[];
  WorkoutSetDraft? previous;
  for (final set in sets) {
    if (previous == set && groups.last.repetitions < 40) {
      groups.last.repetitions++;
    } else {
      groups.add(_RunningSegmentData.fromDraft(set));
      previous = set;
    }
  }
  return groups;
}

String _formatEstimate(RunningWorkoutEstimate estimate) {
  final minimum = _friendlyDuration(estimate.minimumSeconds);
  final maximum = _friendlyDuration(estimate.maximumSeconds);
  return minimum == maximum ? minimum : '$minimum–$maximum';
}

String _friendlyDuration(double seconds) {
  final roundedMinutes = (seconds / 60).round();
  if (roundedMinutes < 60) return '$roundedMinutes min';
  final hours = roundedMinutes ~/ 60;
  final minutes = roundedMinutes % 60;
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}

CreatePersonalWorkoutInput _emptyInput() => CreatePersonalWorkoutInput(
  name: '',
  blocks: [
    WorkoutBlockDraft(
      name: 'Carrera',
      format: WorkoutBlockFormat.running,
      exercises: [
        WorkoutExerciseDraft(
          exerciseId: runningExerciseId,
          sets: [
            WorkoutSetDraft(
              targetType: WorkoutTargetType.distance,
              targetValue: 1000,
              restAfterSeconds: 0,
            ),
          ],
        ),
      ],
    ),
  ],
);

CreatePersonalWorkoutInput _inputFromTemplate(WorkoutTemplate template) {
  final block = template.blocks.single;
  if (block.format != WorkoutBlockFormat.running || block.items.length != 1) {
    throw const FormatException('La sesión no es una carrera editable.');
  }
  return CreatePersonalWorkoutInput(
    name: template.name,
    description: template.description,
    estimatedDurationMinutes: template.estimatedDurationMinutes,
    blocks: [
      WorkoutBlockDraft(
        name: block.name,
        format: WorkoutBlockFormat.running,
        exercises: [
          WorkoutExerciseDraft(
            exerciseId: runningExerciseId,
            sets: block.items.single.sets
                .map(
                  (set) => WorkoutSetDraft(
                    targetType: set.targetDistanceMeters != null
                        ? WorkoutTargetType.distance
                        : WorkoutTargetType.duration,
                    targetValue:
                        set.targetDistanceMeters ??
                        set.targetDurationSeconds!.toDouble(),
                    restAfterSeconds: 0,
                    targetPaceMinSecondsPerKm: set.targetPaceMinSecondsPerKm,
                    targetPaceMaxSecondsPerKm: set.targetPaceMaxSecondsPerKm,
                    recoveryType: set.recoveryType,
                    recoveryDurationSeconds: set.recoveryDurationSeconds,
                    recoveryDistanceMeters: set.recoveryDistanceMeters,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ],
  );
}

int _parseClock(String value) {
  final formatted = parseDurationInput(value);
  if (formatted != null && formatted > 0) return formatted;
  final parts = value.trim().split(':');
  if (parts.length == 1) {
    final seconds = int.tryParse(parts.single);
    if (seconds != null && seconds > 0) return seconds;
  }
  if (parts.length == 2) {
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes != null && minutes >= 0 && seconds != null && seconds < 60) {
      final total = minutes * 60 + seconds;
      if (total > 0) return total;
    }
  }
  throw const FormatException('Usa el formato min:seg.');
}

int? _optionalClock(String value) =>
    value.trim().isEmpty ? null : _parseClock(value);

double _positiveNumber(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null || parsed <= 0) {
    throw const FormatException('Introduce un valor mayor que cero.');
  }
  return parsed;
}

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
