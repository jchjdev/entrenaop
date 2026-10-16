import '../../domain/services/workout_execution_rest_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/services/workout_timer_store.dart';
import '../../domain/services/workout_cue_service.dart';
import '../bloc/active_workout_cubit.dart';
import 'workout_execution_labels.dart';
import 'workout_execution_layout.dart';
import 'workout_result_fields.dart';
import 'workout_exercise_technique.dart';
import 'workout_set_countdown.dart';
import 'workout_effort_field.dart';
import 'performance_result_form.dart';
import 'performance_stopwatch.dart';
import 'duration_input_formatter.dart';

class WorkoutSetEntry extends StatefulWidget {
  const WorkoutSetEntry({
    super.key,
    required this.set,
    required this.executionId,
    required this.timerStore,
    required this.cueService,
    required this.saving,
    required this.onComplete,
    required this.onSkip,
    required this.onSkipWarmUp,
    this.review = false,
    this.records,
  });

  final WorkoutExecutionSet set;
  final String executionId;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;
  final bool saving;
  final void Function(WorkoutSetResultInput result, {int? restSecondsOverride})
  onComplete;
  final void Function({int? restSecondsOverride}) onSkip;
  final VoidCallback onSkipWarmUp;
  final bool review;
  final Widget? records;

  @override
  State<WorkoutSetEntry> createState() => _WorkoutSetEntryState();
}

class _WorkoutSetEntryState extends State<WorkoutSetEntry> {
  final _performanceElapsed = ValueNotifier<double>(0);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _recoveryDurationController;
  late final TextEditingController _recoveryDistanceController;
  late final TextEditingController _loadController;
  double? _actualRpe;
  double? _actualRir;
  int _emomElapsedSeconds = 0;

  WorkoutExecutionSet get set => widget.set;

  @override
  void initState() {
    super.initState();
    // El objetivo sirve como valor inicial, pero el usuario confirma o corrige
    // el resultado real antes de enviarlo.
    _repsController = TextEditingController(
      text: workoutInteger(set.targetReps),
    );
    _durationController = TextEditingController(
      text:
          const [
            WorkoutBlockFormat.running,
            WorkoutBlockFormat.warmUp,
            WorkoutBlockFormat.coolDown,
          ].contains(set.blockFormat)
          ? ''
          : set.targetDurationSeconds == null
          ? ''
          : workoutClock(set.targetDurationSeconds!),
    );
    _distanceController = TextEditingController(
      text:
          set.blockFormat == WorkoutBlockFormat.running &&
              set.targetDurationSeconds != null
          ? ''
          : workoutNullableNumber(set.targetDistanceMeters),
    );
    _recoveryDurationController = TextEditingController();
    _recoveryDistanceController = TextEditingController(
      text: workoutNullableNumber(set.recoveryDistanceMeters),
    );
    _loadController = TextEditingController(
      text: workoutNullableNumber(set.targetLoadKg),
    );
    final draft = context.read<ActiveWorkoutCubit>().state.drafts[set.id];
    final source = draft?.fields;
    final controllers = _controllers;
    if (source != null) {
      for (final entry in controllers.entries) {
        entry.value.text = source[entry.key] ?? '';
      }
      _actualRir = draft!.result.actualRir;
      _actualRpe = draft.result.actualRpe;
    } else if (widget.review) {
      _repsController.text = workoutInteger(set.actualReps);
      _durationController.text = set.actualDurationSeconds == null
          ? ''
          : workoutClock(set.actualDurationSeconds!);
      _distanceController.text = workoutNullableNumber(
        set.actualDistanceMeters,
      );
      _loadController.text = workoutNullableNumber(set.actualLoadKg);
      _recoveryDurationController.text =
          set.actualRecoveryDurationSeconds == null
          ? ''
          : workoutClock(set.actualRecoveryDurationSeconds!);
      _recoveryDistanceController.text = workoutNullableNumber(
        set.actualRecoveryDistanceMeters,
      );
      _actualRir = set.actualRir;
      _actualRpe = set.actualRpe;
    }
    for (final controller in controllers.values) {
      controller.addListener(_persistDraft);
    }
    // El esfuerzo prescrito no acredita una percepción realmente declarada.
    // Si el usuario no lo conoce, guardamos ausencia de dato, nunca el objetivo.
  }

  @override
  void dispose() {
    _performanceElapsed.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _recoveryDurationController.dispose();
    _recoveryDistanceController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  Map<String, TextEditingController> get _controllers => {
    'reps': _repsController,
    'duration': _durationController,
    'distance': _distanceController,
    'load': _loadController,
    'recoveryDuration': _recoveryDurationController,
    'recoveryDistance': _recoveryDistanceController,
  };
  Map<String, String> get _fields => {
    for (final e in _controllers.entries) e.key: e.value.text,
  };
  WorkoutSetResultInput get _input => WorkoutSetResultInput(
    resultId: set.id,
    actualReps: set.targetReps == null
        ? null
        : parseWorkoutReps(_repsController.text),
    actualDurationSeconds:
        set.targetDurationSeconds == null &&
            set.blockFormat != WorkoutBlockFormat.running
        ? null
        : parseDurationInput(_durationController.text),
    actualDistanceMeters:
        set.targetDistanceMeters == null &&
            set.blockFormat != WorkoutBlockFormat.running
        ? null
        : parseWorkoutDecimal(_distanceController.text),
    actualLoadKg: set.targetLoadKg == null
        ? null
        : parseWorkoutDecimal(_loadController.text),
    actualRir: set.targetRir == null ? null : _actualRir,
    actualRpe: set.targetRpe == null ? null : _actualRpe,
    actualRecoveryDurationSeconds: set.recoveryDurationSeconds == null
        ? null
        : parseDurationInput(_recoveryDurationController.text),
    actualRecoveryDistanceMeters: set.recoveryDistanceMeters == null
        ? null
        : parseWorkoutDecimal(_recoveryDistanceController.text),
  );

  void _persistDraft() {
    if (set.performancePrescription != null) return;
    unawaited(context.read<ActiveWorkoutCubit>().updateDraft(_input, _fields));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.review) {
      final success = await context.read<ActiveWorkoutCubit>().confirmDraft(
        _input,
        _fields,
      );
      if (success && mounted) Navigator.pop(context);
    } else {
      widget.onComplete(_input, restSecondsOverride: _restOverride);
    }
  }

  int get _restOverride =>
      workoutRestAfterSet(set, elapsedSeconds: _emomElapsedSeconds);

  Future<void> _end() async {
    final cubit = context.read<ActiveWorkoutCubit>();
    await cubit.updateDraft(_input, _fields);
    await cubit.endCurrentSet(elapsedSeconds: _emomElapsedSeconds);
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Saltar esta serie?'),
        content: const Text(
          'Quedará registrada como omitida y no contará como completada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Saltar serie'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onSkip(
        restSecondsOverride: workoutRestAfterSkipping(
          set,
          elapsedSeconds: _emomElapsedSeconds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualPace = set.blockFormat == WorkoutBlockFormat.running
        ? workoutActualPaceLabel(
            _distanceController.text,
            _durationController.text,
          )
        : null;
    if (set.performancePrescription case final prescription?) {
      final clockSeconds = prescription.measurement == 'DURATION'
          ? prescription.targetValue
          : prescription.fixedDurationSeconds;
      final useStopwatch = const [
        'TIME_FOR_COURSE',
        'TIME_FOR_DISTANCE',
      ].contains(prescription.measurement);
      return SingleChildScrollView(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  set.exerciseName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('Serie ${set.setOrder + 1}'),
                const SizedBox(height: 16),
                PerformanceResultForm(
                  prescription: prescription,
                  saving: widget.saving,
                  initialResult: widget.review ? set.performanceResult : null,
                  elapsedSeconds:
                      widget.review || clockSeconds == null && !useStopwatch
                      ? null
                      : _performanceElapsed,
                  timer: widget.review
                      ? null
                      : clockSeconds == null
                      ? (useStopwatch
                            ? PerformanceStopwatch(
                                onElapsed: (seconds) =>
                                    _performanceElapsed.value = seconds,
                              )
                            : null)
                      : WorkoutSetCountdown(
                          targetSeconds: clockSeconds.ceil(),
                          timerId: '${widget.executionId}:${set.id}',
                          timerStore: widget.timerStore,
                          enabled: !widget.saving,
                          onElapsedChanged: (elapsed) =>
                              _performanceElapsed.value = elapsed.toDouble(),
                          onPreparationTick: () => unawaited(
                            widget.cueService.signal(
                              WorkoutCue.preparationTick,
                            ),
                          ),
                          onStarted: () => unawaited(
                            widget.cueService.signal(WorkoutCue.workStarted),
                          ),
                          onHalfway: () => unawaited(
                            widget.cueService.signal(WorkoutCue.halfway),
                          ),
                          onTenSecondsRemaining: () => unawaited(
                            widget.cueService.signal(
                              WorkoutCue.tenSecondsRemaining,
                            ),
                          ),
                          onEndingTick: (_) => unawaited(
                            widget.cueService.signal(WorkoutCue.workEndingTick),
                          ),
                          onFinished: () => unawaited(
                            widget.cueService.signal(WorkoutCue.workFinished),
                          ),
                        ),
                  onSave: (result, _) async {
                    final input = WorkoutSetResultInput(
                      resultId: set.id,
                      performanceResult: result,
                    );
                    if (widget.review) {
                      final success = await context
                          .read<ActiveWorkoutCubit>()
                          .confirmDraft(input, const {});
                      if (success && context.mounted) Navigator.pop(context);
                    } else {
                      widget.onComplete(input);
                    }
                  },
                ),
                TextButton(
                  onPressed: widget.saving ? null : _confirmSkip,
                  child: const Text('Omitir esta serie'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final imageUrl = context
        .read<ActiveWorkoutCubit>()
        .state
        .exercises[set.exerciseId]
        ?.thumbnailUrl;
    final expandImage = !widget.review && imageUrl?.trim().isNotEmpty == true;
    final header = WorkoutExerciseHeader(
      name: set.exerciseName,
      position:
          '${set.blockName} · ${set.isGrouped ? workoutPositionLabel(set) : 'Serie ${set.setOrder + 1}'}',
      expandImage: expandImage,
      imageUrl: imageUrl,
      onTechnique: () => showWorkoutTechnique(context, set),
    );
    return WorkoutExecutionFrame(
      fillViewport: expandImage,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: widget.saving
                ? null
                : widget.review
                ? _save
                : _end,
            icon: const Icon(Icons.check_rounded),
            label: Text(
              widget.saving
                  ? 'Guardando…'
                  : widget.review
                  ? 'Confirmar datos'
                  : 'Terminar serie',
            ),
          ),
          if (!widget.review) ...[
            Row(
              children: [
                if (widget.records != null) Expanded(child: widget.records!),
                if (set.blockFormat != WorkoutBlockFormat.warmUp)
                  TextButton(
                    onPressed: widget.saving ? null : _confirmSkip,
                    child: const Text('Omitir'),
                  ),
              ],
            ),
          ],
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.review)
              if (expandImage) Expanded(child: header) else header
            else
              Text(
                set.exerciseName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (set.itemInstructions?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                set.itemInstructions!,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
            if (set.blockFormat == WorkoutBlockFormat.warmUp && !widget.review)
              TextButton(
                onPressed: widget.saving ? null : widget.onSkipWarmUp,
                child: const Text('Omitir calentamiento'),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Objetivo · ${workoutTargetLabel(set)}',
                  style: TextStyle(
                    fontSize: set.targetDurationSeconds == null ? 20 : 14,
                    fontWeight: FontWeight.w800,
                    color: set.targetDurationSeconds == null
                        ? const Color(0xFFFFA06F)
                        : Colors.white70,
                  ),
                ),
                if (set.targetRir != null)
                  Text(
                    'RIR ${workoutNumber(set.targetRir!)}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                if (set.targetRpe != null)
                  Text(
                    'RPE ${workoutNumber(set.targetRpe!)}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                if (set.targetLoadKg != null)
                  Text(
                    '${workoutNumber(set.targetLoadKg!)} kg',
                    style: const TextStyle(color: Colors.white60),
                  ),
              ],
            ),
            if (set.targetPaceMinSecondsPerKm case final fastest?) ...[
              const SizedBox(height: 7),
              Text(
                fastest == set.targetPaceMaxSecondsPerKm
                    ? 'Ritmo objetivo: ${workoutClock(fastest)}/km'
                    : 'Ritmo objetivo: ${workoutClock(fastest)}–${workoutClock(set.targetPaceMaxSecondsPerKm!)}/km',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (workoutTargetTimeLabel(set) case final targetTime?) ...[
              const SizedBox(height: 7),
              Text(
                targetTime,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
            ],
            if (set.recoveryType case final recovery?) ...[
              const SizedBox(height: 7),
              Text(
                'Después: ${workoutRunningRecoveryLabel(recovery, set)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFC2A3)),
              ),
            ],
            if (!widget.review &&
                set.blockFormat == WorkoutBlockFormat.emom) ...[
              const SizedBox(height: 22),
              WorkoutSetCountdown(
                targetSeconds: 60,
                compact: true,
                preparationSeconds: set.itemOrder == 0 && set.setOrder == 0
                    ? 3
                    : 0,
                autoStart: true,
                title: 'RELOJ EMOM · VUELTA ${set.roundNumber}',
                timerId: '${widget.executionId}:${set.id}',
                timerStore: widget.timerStore,
                enabled: !widget.saving,
                onElapsedChanged: (elapsed) {
                  _emomElapsedSeconds = elapsed;
                },
                onPreparationTick: () => unawaited(
                  widget.cueService.signal(WorkoutCue.preparationTick),
                ),
                onStarted: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.workStarted)),
                onHalfway: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.halfway)),
                onTenSecondsRemaining: () => unawaited(
                  widget.cueService.signal(WorkoutCue.tenSecondsRemaining),
                ),
                onEndingTick: (_) => unawaited(
                  widget.cueService.signal(WorkoutCue.workEndingTick),
                ),
                onFinished: () => unawaited(
                  widget.cueService.signal(WorkoutCue.workFinished),
                ),
              ),
            ] else if (!widget.review && set.targetDurationSeconds != null) ...[
              const SizedBox(height: 22),
              WorkoutSetCountdown(
                targetSeconds: set.targetDurationSeconds!,
                compact: true,
                timerId: '${widget.executionId}:${set.id}',
                timerStore: widget.timerStore,
                enabled: !widget.saving,
                onElapsedChanged: (elapsed) {
                  _durationController.text = workoutClock(elapsed);
                },
                onPreparationTick: () => unawaited(
                  widget.cueService.signal(WorkoutCue.preparationTick),
                ),
                onStarted: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.workStarted)),
                onHalfway: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.halfway)),
                onTenSecondsRemaining: () => unawaited(
                  widget.cueService.signal(WorkoutCue.tenSecondsRemaining),
                ),
                onEndingTick: (_) => unawaited(
                  widget.cueService.signal(WorkoutCue.workEndingTick),
                ),
                onFinished: () => unawaited(
                  widget.cueService.signal(WorkoutCue.workFinished),
                ),
              ),
            ],
            if (widget.review || set.targetDurationSeconds == null) ...[
              const SizedBox(height: 14),
              const Text(
                'Tu resultado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (set.targetReps != null)
                WorkoutNumberResultField(
                  enabled: !widget.saving,
                  controller: _repsController,
                  label: 'Repeticiones realizadas',
                  decimal: false,
                ),
              if (set.targetDurationSeconds != null ||
                  set.blockFormat == WorkoutBlockFormat.running)
                set.blockFormat == WorkoutBlockFormat.running
                    ? WorkoutDurationResultField(
                        enabled: !widget.saving,
                        controller: _durationController,
                        label: 'Tiempo real',
                        onChanged: (_) => setState(() {}),
                      )
                    : WorkoutDurationResultField(
                        enabled: !widget.saving,
                        controller: _durationController,
                        label: 'Tiempo realizado',
                      ),
              if (set.targetDistanceMeters != null ||
                  set.blockFormat == WorkoutBlockFormat.running)
                WorkoutNumberResultField(
                  enabled: !widget.saving,
                  controller: _distanceController,
                  label: 'Metros realizados',
                  onChanged: set.blockFormat == WorkoutBlockFormat.running
                      ? (_) => setState(() {})
                      : null,
                ),
              if (actualPace != null) ...[
                Text(
                  'Ritmo calculado · $actualPace/km',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFA06F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (set.recoveryDurationSeconds != null)
                WorkoutDurationResultField(
                  enabled: !widget.saving,
                  controller: _recoveryDurationController,
                  label: 'Recuperación real',
                ),
              if (set.recoveryDistanceMeters != null)
                WorkoutNumberResultField(
                  enabled: !widget.saving,
                  controller: _recoveryDistanceController,
                  label: 'Metros reales de recuperación',
                ),
              if (set.targetLoadKg != null)
                WorkoutNumberResultField(
                  enabled: !widget.saving,
                  controller: _loadController,
                  label: 'Carga utilizada (kg)',
                ),
              if (set.targetRpe != null)
                WorkoutEffortField(
                  value: _actualRpe,
                  label: set.blockFormat == WorkoutBlockFormat.running
                      ? 'Esfuerzo de carrera · 1 fácil, 10 máximo'
                      : 'RPE real',
                  minimum: 1,
                  enabled: !widget.saving,
                  onChanged: (value) {
                    setState(() => _actualRpe = value);
                    _persistDraft();
                  },
                ),
              if (set.targetRir != null)
                WorkoutEffortField(
                  value: _actualRir,
                  label: 'RIR real',
                  minimum: 0,
                  enabled: !widget.saving,
                  onChanged: (value) {
                    setState(() => _actualRir = value);
                    _persistDraft();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
