import '../../domain/services/workout_execution_rest_policy.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/services/workout_timer_store.dart';
import '../../domain/services/workout_cue_service.dart';
import '../../domain/services/workout_session_draft_store.dart';
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
import 'workout_inline_records.dart';

typedef WorkoutSetDraftEditor = ({
  WorkoutSessionSetDraft? initial,
  Future<void> Function(WorkoutSetResultInput, Map<String, String>) update,
  Future<bool> Function(WorkoutSetResultInput, Map<String, String>) confirm,
});

class WorkoutSetEntry extends StatefulWidget {
  const WorkoutSetEntry({
    super.key,
    required this.set,
    required this.executionId,
    required this.timerStore,
    required this.cueService,
    required this.saving,
    this.onComplete,
    this.onSkip,
    this.onSkipWarmUp,
    this.review = false,
    this.reviewEditor,
    this.records,
    this.onStartPhoneRun,
    this.guidedPhoneRun = false,
    this.scrollActionsWithContent = false,
  });

  final WorkoutExecutionSet set;
  final String executionId;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;
  final bool saving;
  final void Function(WorkoutSetResultInput result, {int? restSecondsOverride})?
  onComplete;
  final void Function({int? restSecondsOverride})? onSkip;
  final VoidCallback? onSkipWarmUp;
  final bool review;
  final WorkoutSetDraftEditor? reviewEditor;
  final Widget? records;
  final VoidCallback? onStartPhoneRun;
  final bool guidedPhoneRun;
  final bool scrollActionsWithContent;

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
  late final _measure = WorkoutInlineField.forSet(set)?.first;
  bool _measureEntered = false;

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
    // La carga prescrita orienta la serie. Solo se registra la carga declarada.
    _loadController = TextEditingController();
    final draft = widget.reviewEditor != null
        ? widget.reviewEditor!.initial
        : context.read<ActiveWorkoutCubit>().state.drafts[set.id];
    final source = draft?.fields;
    final controllers = _controllers;
    if (source != null && (source.isNotEmpty || widget.reviewEditor == null)) {
      for (final entry in controllers.entries) {
        entry.value.text = source[entry.key] ?? '';
      }
      _actualRir = draft!.result.actualRir;
      _actualRpe = draft.result.actualRpe;
    } else if (widget.review) {
      final result = draft?.result;
      final duration =
          result?.actualDurationSeconds ?? set.actualDurationSeconds;
      _repsController.text = workoutInteger(
        result?.actualReps ?? set.actualReps,
      );
      _durationController.text = duration == null ? '' : workoutClock(duration);
      _distanceController.text = workoutNullableNumber(
        result?.actualDistanceMeters ?? set.actualDistanceMeters,
      );
      _loadController.text = workoutNullableNumber(
        result?.actualLoadKg ?? set.actualLoadKg,
      );
      final recoveryDuration =
          result?.actualRecoveryDurationSeconds ??
          set.actualRecoveryDurationSeconds;
      _recoveryDurationController.text = recoveryDuration == null
          ? ''
          : workoutClock(recoveryDuration);
      _recoveryDistanceController.text = workoutNullableNumber(
        result?.actualRecoveryDistanceMeters ??
            set.actualRecoveryDistanceMeters,
      );
      _actualRir = result?.actualRir ?? set.actualRir;
      _actualRpe = result?.actualRpe ?? set.actualRpe;
    }
    _measureEntered = draft?.hasMeasuredResult == true;
    for (final entry in controllers.entries) {
      var lastText = entry.value.text;
      entry.value.addListener(() {
        final text = entry.value.text;
        if (text == lastText) return;
        lastText = text;
        if (entry.key == _measure?.name) _measureEntered = true;
        _persistDraft();
      });
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
  WorkoutSetResultInput get _input => _resultInput();

  WorkoutSetResultInput _resultInput({bool forDraft = false}) =>
      WorkoutSetResultInput(
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
        actualLoadKg: set.supportsLoadRecording
            ? parseWorkoutDecimal(_loadController.text)
            : null,
        // El borrador puede conservar un dato heredado que ya no corresponde
        // enviar como resultado nuevo de esta tarea.
        actualRir: forDraft
            ? _actualRir
            : !set.usesRir || set.targetRir == null
            ? null
            : _actualRir,
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
    unawaited(_updateDraft());
  }

  Future<void> _updateDraft() {
    final result = _resultInput(forDraft: true);
    final reviewEditor = widget.reviewEditor;
    if (reviewEditor != null) return reviewEditor.update(result, _fields);
    return context.read<ActiveWorkoutCubit>().updateDraft(
      result,
      _fields,
      hasMeasuredResult: _measure != null && _measureEntered,
    );
  }

  Future<bool> _confirm(
    WorkoutSetResultInput input,
    Map<String, String> fields,
  ) =>
      (widget.reviewEditor?.confirm ??
      context.read<ActiveWorkoutCubit>().confirmDraft)(input, fields);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.review) {
      final success = await _confirm(_input, _fields);
      if (success && mounted) Navigator.pop(context);
    } else {
      widget.onComplete?.call(_input, restSecondsOverride: _restOverride);
    }
  }

  int get _restOverride =>
      workoutRestAfterSet(set, elapsedSeconds: _emomElapsedSeconds);

  Future<void> _end() async {
    final cubit = context.read<ActiveWorkoutCubit>();
    await _updateDraft();
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
      widget.onSkip?.call(
        restSecondsOverride: workoutRestAfterSkipping(
          set,
          elapsedSeconds: _emomElapsedSeconds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWarmup = set.blockFormat == WorkoutBlockFormat.warmUp;
    final skipWarmup =
        isWarmup &&
            !widget.review &&
            set.warmupCanBeSkipped &&
            widget.onSkipWarmUp != null
        ? TextButton(
            onPressed: widget.saving ? null : widget.onSkipWarmUp,
            child: const Text('Omitir calentamiento'),
          )
        : null;
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
                ?skipWarmup,
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
                      final success = await _confirm(input, const {});
                      if (success && context.mounted) Navigator.pop(context);
                    } else {
                      widget.onComplete?.call(input);
                    }
                  },
                ),
                if (!isWarmup && widget.reviewEditor == null)
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
    final imageUrl = set.imageForExecution(
      widget.reviewEditor == null
          ? context
                .read<ActiveWorkoutCubit>()
                .state
                .exercises[set.exerciseId]
                ?.thumbnailUrl
          : null,
    );
    final startPhoneRun = widget.onStartPhoneRun;
    final expandImage =
        !widget.scrollActionsWithContent &&
        !widget.review &&
        imageUrl?.trim().isNotEmpty == true;
    final header = WorkoutExerciseHeader(
      name: set.exerciseName,
      position:
          '${set.blockName} · ${set.isGrouped ? workoutPositionLabel(set) : 'Serie ${set.setOrder + 1}'}',
      expandImage: expandImage,
      imageUrl: imageUrl,
      onTechnique: () => showWorkoutTechnique(context, set),
    );
    final finishSeries = widget.saving
        ? null
        : widget.review
        ? _save
        : _end;
    final finishLabel = Text(
      widget.saving
          ? 'Guardando…'
          : widget.review
          ? 'Confirmar datos'
          : 'Terminar serie',
    );
    return WorkoutExecutionFrame(
      fillViewport: expandImage,
      scrollActionsWithContent: widget.scrollActionsWithContent,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startPhoneRun == null)
            FilledButton.icon(
              onPressed: finishSeries,
              icon: const Icon(Icons.check_rounded),
              label: finishLabel,
            )
          else
            OutlinedButton.icon(
              onPressed: finishSeries,
              icon: const Icon(Icons.check_rounded),
              label: finishLabel,
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
              InkWell(
                onTap: () => showWorkoutTechnique(context, set),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          set.itemInstructions!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        semanticLabel: 'Ver indicaciones completas',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ?skipWarmup,
            if (set.runningStep?.completion == RunningStepCompletion.manual)
              const Text(
                'Avanza cuando estés preparado. En el reloj, pulsa Lap.',
                textAlign: TextAlign.center,
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
                if (set.usesRir && set.targetRir != null)
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
            if (startPhoneRun != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.saving ? null : startPhoneRun,
                icon: const Icon(Icons.gps_fixed_rounded),
                label: Text(
                  widget.guidedPhoneRun
                      ? 'Entrenar con el móvil'
                      : 'Grabar con el móvil',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.guidedPhoneRun
                    ? 'Te avisa al cambiar de tramo y registra los parciales.'
                    : 'Mide tiempo y distancia con GPS.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              WorkoutSetCountdown(
                targetSeconds: set.targetDurationSeconds!,
                compact: true,
                timerId: '${widget.executionId}:${set.id}',
                timerStore: widget.timerStore,
                enabled: !widget.saving,
                onElapsedChanged: (elapsed) {
                  final text = workoutClock(elapsed);
                  if (_measure == WorkoutInlineField.duration &&
                      elapsed > 0 &&
                      !_measureEntered &&
                      _durationController.text == text) {
                    // El cronómetro puede medir justo el tiempo sugerido.
                    _measureEntered = true;
                    _persistDraft();
                  }
                  _durationController.text = text;
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
                  optional: set.manualDistanceOptional,
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
              if (set.supportsLoadRecording)
                WorkoutNumberResultField(
                  enabled: !widget.saving,
                  controller: _loadController,
                  label: 'Carga (kg)',
                  optional: true,
                ),
              if (set.targetRpe != null)
                WorkoutEffortField(
                  value: _actualRpe,
                  label: set.blockFormat == WorkoutBlockFormat.running
                      ? 'Esfuerzo de carrera · 1 fácil, 10 máximo'
                      : 'RPE real',
                  minimum: 1,
                  wholeNumbersOnly: true,
                  enabled: !widget.saving,
                  onChanged: (value) {
                    setState(() => _actualRpe = value);
                    _persistDraft();
                  },
                ),
              if (set.usesRir && set.targetRir != null)
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
