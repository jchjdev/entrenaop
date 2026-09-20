import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WorkoutPreviewPage extends StatelessWidget {
  const WorkoutPreviewPage({super.key});

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
        title: const Text('Vista de la sesión'),
      ),
      body: BlocConsumer<WorkoutPreviewCubit, WorkoutPreviewState>(
        listener: (context, state) {
          final executionId = state.executionId;
          if (executionId != null) {
            context.push('/plan/starter-session/active/$executionId');
          }
        },
        builder: (context, state) => switch (state.status) {
          WorkoutPreviewStatus.initial || WorkoutPreviewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          WorkoutPreviewStatus.empty => const _Message(
            icon: Icons.fitness_center_outlined,
            text: 'La sesión todavía no está disponible.',
          ),
          WorkoutPreviewStatus.failure when state.workout == null => _Message(
            icon: Icons.cloud_off_outlined,
            text: state.errorMessage ?? 'No hemos podido cargar la sesión.',
            action: FilledButton(
              onPressed: context.read<WorkoutPreviewCubit>().load,
              child: const Text('Reintentar'),
            ),
          ),
          WorkoutPreviewStatus.ready ||
          WorkoutPreviewStatus.starting ||
          WorkoutPreviewStatus.failure => _WorkoutContent(
            workout: state.workout!,
            starting: state.status == WorkoutPreviewStatus.starting,
            errorMessage: state.errorMessage,
          ),
        },
      ),
    );
  }
}

class _WorkoutContent extends StatelessWidget {
  const _WorkoutContent({
    required this.workout,
    required this.starting,
    this.errorMessage,
  });

  final WorkoutTemplate workout;
  final bool starting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(workout: workout),
                    const SizedBox(height: 18),
                    for (final (index, block) in workout.blocks.indexed) ...[
                      _BlockCard(number: index + 1, block: block),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 6),
                    if (errorMessage case final message?) ...[
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      onPressed: starting
                          ? null
                          : context.read<WorkoutPreviewCubit>().start,
                      icon: starting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        starting ? 'Preparando sesión…' : 'Empezar sesión',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Esta es una sesión pública de validación, no una recomendación personalizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.workout});

  final WorkoutTemplate workout;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFFFF8A50),
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              workout.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            if (workout.description case final description?) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (workout.estimatedDurationMinutes case final minutes?)
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label: '$minutes min',
                  ),
                _InfoChip(
                  icon: Icons.view_agenda_outlined,
                  label: '${workout.blocks.length} bloques',
                ),
                _InfoChip(
                  icon: Icons.history_rounded,
                  label: 'Versión ${workout.version}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white60),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.number, required this.block});

  final int number;
  final WorkoutBlock block;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141414),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0x33FF8A50),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFFFF8A50),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _blockDescription(block),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final (index, item) in block.items.indexed) ...[
              if (index > 0) const Divider(height: 24),
              _ExerciseRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.item});

  final WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          _setSummary(item.sets),
          style: const TextStyle(
            color: Color(0xFFFFA06F),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item.notes case final notes?) ...[
          const SizedBox(height: 5),
          Text(notes, style: const TextStyle(color: Colors.white60)),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.white38),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action case final action?) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

String _blockDescription(WorkoutBlock block) {
  final format = switch (block.format) {
    WorkoutBlockFormat.straightSets => 'Series convencionales',
    WorkoutBlockFormat.circuit => 'Circuito',
    WorkoutBlockFormat.superset => 'Superserie',
    WorkoutBlockFormat.intervals => 'Intervalos',
    WorkoutBlockFormat.emom => 'EMOM',
    WorkoutBlockFormat.amrap => 'AMRAP',
    WorkoutBlockFormat.tabata => 'Tabata',
    WorkoutBlockFormat.warmUp => 'Calentamiento',
    WorkoutBlockFormat.coolDown => 'Vuelta a la calma',
  };
  return block.rounds > 1 ? '$format · ${block.rounds} rondas' : format;
}

String _setSummary(List<WorkoutSet> sets) {
  if (sets.isEmpty) return 'Sin series prescritas';
  final first = sets.first;
  final target = switch ((
    first.targetReps,
    first.targetDurationSeconds,
    first.targetDistanceMeters,
  )) {
    (final int reps, _, _) => '$reps repeticiones',
    (_, final int seconds, _) => '${_duration(seconds)} de trabajo',
    (_, _, final double meters) => '${_number(meters)} m',
    _ => 'objetivo configurado',
  };
  final rest = first.restAfterSeconds > 0
      ? ' · ${_duration(first.restAfterSeconds)} descanso'
      : '';
  return '${sets.length} × $target$rest';
}

String _duration(int seconds) {
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return remainder == 0
      ? '$minutes min'
      : '$minutes:${remainder.toString().padLeft(2, '0')} min';
}

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
