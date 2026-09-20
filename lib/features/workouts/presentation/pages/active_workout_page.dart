import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ActiveWorkoutPage extends StatelessWidget {
  const ActiveWorkoutPage({required this.timerStore, super.key});

  final WorkoutTimerStore timerStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Pausar y salir',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) => Text(switch (state.status) {
            ActiveWorkoutStatus.completed => 'Sesión completada',
            ActiveWorkoutStatus.abandoned => 'Sesión cerrada',
            _ => 'Sesión en curso',
          }),
        ),
      ),
      body: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
        builder: (context, state) {
          if (state.status == ActiveWorkoutStatus.initial ||
              state.status == ActiveWorkoutStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final execution = state.execution;
          if (execution == null) {
            return _Failure(
              message: state.errorMessage ?? 'No hemos podido abrir la sesión.',
              onRetry: context.read<ActiveWorkoutCubit>().load,
            );
          }
          if (state.status == ActiveWorkoutStatus.completed ||
              execution.status == WorkoutExecutionStatus.completed) {
            return _Completed(execution: execution);
          }
          if (state.status == ActiveWorkoutStatus.abandoned ||
              execution.status == WorkoutExecutionStatus.abandoned) {
            return _Abandoned(execution: execution);
          }
          return _ActiveContent(state: state, timerStore: timerStore);
        },
      ),
    );
  }
}

class _ActiveContent extends StatefulWidget {
  const _ActiveContent({required this.state, required this.timerStore});

  final ActiveWorkoutState state;
  final WorkoutTimerStore timerStore;

  @override
  State<_ActiveContent> createState() => _ActiveContentState();
}

class _ActiveContentState extends State<_ActiveContent> {
  double _finalRpe = 7;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final execution = state.execution!;
    final current = execution.currentSet;
    final saving = state.status == ActiveWorkoutStatus.saving;

    return SafeArea(
      child: Center(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      execution.templateName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: execution.sets.isEmpty
                          ? 0
                          : execution.resolvedSetCount / execution.sets.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _progressLabel(execution),
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 22),
                    if (state.status == ActiveWorkoutStatus.resting)
                      _RestCard(
                        seconds: state.restSecondsRemaining,
                        onSkip: context.read<ActiveWorkoutCubit>().skipRest,
                      )
                    else if (current != null)
                      _CurrentSetCard(
                        key: ValueKey(current.id),
                        set: current,
                        executionId: execution.id,
                        timerStore: widget.timerStore,
                        saving: saving,
                        onComplete: context
                            .read<ActiveWorkoutCubit>()
                            .completeCurrentSet,
                        onSkip: context
                            .read<ActiveWorkoutCubit>()
                            .skipCurrentSet,
                      )
                    else
                      _FinishCard(
                        rpe: _finalRpe,
                        saving: saving,
                        onChanged: (value) => setState(() => _finalRpe = value),
                        onFinish: () => context
                            .read<ActiveWorkoutCubit>()
                            .finish(_finalRpe.round()),
                      ),
                    if (state.status == ActiveWorkoutStatus.failure &&
                        state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    if (current != null ||
                        state.status == ActiveWorkoutStatus.resting) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Puedes salir y continuar después: el progreso guardado no se pierde.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                      TextButton.icon(
                        onPressed: saving ? null : _requestAbandonment,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text(
                          'Abandonar la sesión definitivamente',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAbandonment() async {
    final reason = await showDialog<WorkoutAbandonmentReason>(
      context: context,
      builder: (dialogContext) {
        WorkoutAbandonmentReason? selected;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Abandonar sesión'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La sesión se cerrará, pero conservaremos todo lo que ya has realizado. ¿Cuál es el motivo?',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WorkoutAbandonmentReason.values
                      .map(
                        (reason) => ChoiceChip(
                          label: Text(_abandonmentReasonLabel(reason)),
                          selected: selected == reason,
                          onSelected: (_) {
                            setDialogState(() => selected = reason);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Seguir entrenando'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, selected),
                child: const Text('Confirmar abandono'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;
    await context.read<ActiveWorkoutCubit>().abandon(reason);
  }
}

class _CurrentSetCard extends StatefulWidget {
  const _CurrentSetCard({
    super.key,
    required this.set,
    required this.executionId,
    required this.timerStore,
    required this.saving,
    required this.onComplete,
    required this.onSkip,
  });

  final WorkoutExecutionSet set;
  final String executionId;
  final WorkoutTimerStore timerStore;
  final bool saving;
  final ValueChanged<WorkoutSetResultInput> onComplete;
  final VoidCallback onSkip;

  @override
  State<_CurrentSetCard> createState() => _CurrentSetCardState();
}

class _CurrentSetCardState extends State<_CurrentSetCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _loadController;
  late double _actualRpe;
  late double _actualRir;

  WorkoutExecutionSet get set => widget.set;

  @override
  void initState() {
    super.initState();
    // El objetivo sirve como valor inicial, pero el usuario confirma o corrige
    // el resultado real antes de enviarlo.
    _repsController = TextEditingController(text: _integer(set.targetReps));
    _durationController = TextEditingController(
      text: _integer(set.targetDurationSeconds),
    );
    _distanceController = TextEditingController(
      text: _nullableNumber(set.targetDistanceMeters),
    );
    _loadController = TextEditingController(
      text: _nullableNumber(set.targetLoadKg),
    );
    _actualRpe = (set.targetRpe ?? 7).clamp(1, 10).toDouble();
    _actualRir = (set.targetRir ?? 2).clamp(0, 10).toDouble();
  }

  @override
  void dispose() {
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onComplete(
      WorkoutSetResultInput(
        resultId: set.id,
        actualReps: set.targetReps == null
            ? null
            : _parseDecimal(_repsController.text)!.toInt(),
        actualDurationSeconds: set.targetDurationSeconds == null
            ? null
            : _parseDecimal(_durationController.text)!.toInt(),
        actualDistanceMeters: set.targetDistanceMeters == null
            ? null
            : _parseDecimal(_distanceController.text),
        actualLoadKg: set.targetLoadKg == null
            ? null
            : _parseDecimal(_loadController.text),
        actualRpe: set.targetRpe == null ? null : _actualRpe,
        actualRir: set.targetRir == null ? null : _actualRir,
      ),
    );
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
    if (confirmed == true && mounted) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                set.blockName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFF8A50),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                set.exerciseName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Serie ${set.setOrder + 1}',
                style: const TextStyle(color: Colors.white60, fontSize: 17),
              ),
              const SizedBox(height: 28),
              Text(
                _target(set),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFA06F),
                ),
              ),
              if (set.targetRir case final rir?) ...[
                const SizedBox(height: 7),
                Text(
                  'Objetivo: RIR ${_number(rir)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
              if (set.targetDurationSeconds case final seconds?) ...[
                const SizedBox(height: 22),
                WorkoutSetCountdown(
                  targetSeconds: seconds,
                  timerId: '${widget.executionId}:${set.id}',
                  timerStore: widget.timerStore,
                  enabled: !widget.saving,
                  onElapsedChanged: (elapsed) {
                    _durationController.text = elapsed.toString();
                  },
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                '¿Qué has hecho realmente?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (set.targetReps != null)
                _ResultField(
                  controller: _repsController,
                  label: 'Repeticiones realizadas',
                  decimal: false,
                ),
              if (set.targetDurationSeconds != null)
                _ResultField(
                  controller: _durationController,
                  label: 'Segundos realizados',
                  decimal: false,
                ),
              if (set.targetDistanceMeters != null)
                _ResultField(
                  controller: _distanceController,
                  label: 'Metros realizados',
                ),
              if (set.targetLoadKg != null)
                _ResultField(
                  controller: _loadController,
                  label: 'Carga utilizada (kg)',
                ),
              if (set.targetRpe != null) ...[
                Text('RPE real · ${_number(_actualRpe)}'),
                Slider(
                  value: _actualRpe,
                  min: 1,
                  max: 10,
                  divisions: 18,
                  onChanged: widget.saving
                      ? null
                      : (value) => setState(() => _actualRpe = value),
                ),
              ],
              if (set.targetRir != null) ...[
                Text('RIR real · ${_number(_actualRir)}'),
                Slider(
                  value: _actualRir,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  onChanged: widget.saving
                      ? null
                      : (value) => setState(() => _actualRir = value),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.saving ? null : _save,
                icon: widget.saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(widget.saving ? 'Guardando…' : 'Guardar serie'),
              ),
              TextButton(
                onPressed: widget.saving ? null : _confirmSkip,
                child: const Text('No he podido hacerla · Saltar serie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultField extends StatelessWidget {
  const _ResultField({
    required this.controller,
    required this.label,
    this.decimal = true,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = _parseDecimal(value ?? '');
          if (parsed == null) return 'Introduce un número válido';
          if (parsed < 0) return 'El valor no puede ser negativo';
          if (!decimal && parsed != parsed.roundToDouble()) {
            return 'Introduce un número entero';
          }
          return null;
        },
      ),
    );
  }
}

class _RestCard extends StatelessWidget {
  const _RestCard({required this.seconds, required this.onSkip});

  final int seconds;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 44,
              color: Color(0xFFFF8A50),
            ),
            const SizedBox(height: 12),
            const Text('Descanso', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              _clock(seconds),
              style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900),
            ),
            TextButton(onPressed: onSkip, child: const Text('Saltar descanso')),
          ],
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.rpe,
    required this.saving,
    required this.onChanged,
    required this.onFinish,
  });

  final double rpe;
  final bool saving;
  final ValueChanged<double> onChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 42,
              color: Color(0xFFFF8A50),
            ),
            const SizedBox(height: 12),
            const Text(
              'Todas las series completadas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              'Esfuerzo global · RPE ${rpe.round()}',
              textAlign: TextAlign.center,
            ),
            Slider(
              value: rpe,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: onChanged,
            ),
            FilledButton(
              onPressed: saving ? null : onFinish,
              child: Text(saving ? 'Guardando…' : 'Finalizar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Completed extends StatelessWidget {
  const _Completed({required this.execution});

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 68,
              color: Color(0xFFFF8A50),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sesión completada',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${execution.completedSetCount} completadas'
              '${execution.skippedSetCount == 0 ? '' : ' · ${execution.skippedSetCount} omitidas'}'
              ' · RPE ${execution.finalRpe ?? '-'}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/plan'),
              child: const Text('Volver a Mi plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Abandoned extends StatelessWidget {
  const _Abandoned({required this.execution});

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    final reason = execution.abandonmentReason;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 68, color: Color(0xFFFFA06F)),
            const SizedBox(height: 16),
            const Text(
              'Sesión cerrada',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${execution.completedSetCount} '
              '${execution.completedSetCount == 1 ? 'serie completada' : 'series completadas'}'
              '${reason == null ? '' : ' · ${_abandonmentReasonLabel(reason)}'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lo realizado se conserva para tu historial.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context.go('/plan'),
              child: const Text('Volver a Mi plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

String _target(WorkoutExecutionSet set) {
  if (set.targetReps != null) return '${set.targetReps} repeticiones';
  if (set.targetDurationSeconds != null) {
    return '${set.targetDurationSeconds} segundos';
  }
  if (set.targetDistanceMeters != null) {
    return '${_number(set.targetDistanceMeters!)} metros';
  }
  return 'Objetivo configurado';
}

String _clock(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

String _integer(int? value) => value?.toString() ?? '';

String _nullableNumber(double? value) => value == null ? '' : _number(value);

double? _parseDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _progressLabel(WorkoutExecution execution) {
  final completed = execution.completedSetCount;
  final skipped = execution.skippedSetCount;
  if (skipped == 0) {
    return '$completed de ${execution.sets.length} series completadas';
  }
  return '${execution.resolvedSetCount} de ${execution.sets.length} resueltas '
      '($completed completadas, $skipped omitidas)';
}

String _abandonmentReasonLabel(WorkoutAbandonmentReason reason) =>
    switch (reason) {
      WorkoutAbandonmentReason.lackOfTime => 'Falta de tiempo',
      WorkoutAbandonmentReason.tooDifficult => 'Demasiada dificultad',
      WorkoutAbandonmentReason.discomfort => 'Molestias',
      WorkoutAbandonmentReason.other => 'Otro motivo',
    };
