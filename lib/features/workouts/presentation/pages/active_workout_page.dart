import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ActiveWorkoutPage extends StatelessWidget {
  const ActiveWorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Sesión en curso'),
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
          return _ActiveContent(state: state);
        },
      ),
    );
  }
}

class _ActiveContent extends StatefulWidget {
  const _ActiveContent({required this.state});

  final ActiveWorkoutState state;

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
                          : execution.completedSetCount / execution.sets.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${execution.completedSetCount} de ${execution.sets.length} series completadas',
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
                        set: current,
                        saving: saving,
                        onComplete: context
                            .read<ActiveWorkoutCubit>()
                            .completeCurrentSet,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentSetCard extends StatelessWidget {
  const _CurrentSetCard({
    required this.set,
    required this.saving,
    required this.onComplete,
  });

  final WorkoutExecutionSet set;
  final bool saving;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
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
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: saving ? null : onComplete,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(saving ? 'Guardando…' : 'Serie completada'),
            ),
          ],
        ),
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
              '${execution.sets.length} series registradas · RPE ${execution.finalRpe ?? '-'}',
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
