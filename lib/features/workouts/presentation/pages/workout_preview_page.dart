import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WorkoutPreviewPage extends StatelessWidget {
  const WorkoutPreviewPage({required this.routeBase, super.key});

  final String routeBase;

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
            context.push('$routeBase/active/$executionId');
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
                      'Comprueba la sesión antes de empezar. Durante el entrenamiento podrás registrar el resultado real de cada serie.',
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
                        _blockFormatLabel(block.format),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _blockPlanSummary(block),
              style: const TextStyle(
                color: Color(0xFFFFA06F),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_showsSequence(block.format)) ...[
              const SizedBox(height: 12),
              _SequenceOverview(block: block),
            ],
            const SizedBox(height: 14),
            for (final (index, item) in block.items.indexed) ...[
              if (index > 0) const Divider(height: 24),
              _ExerciseRow(block: block, index: index, item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _SequenceOverview extends StatelessWidget {
  const _SequenceOverview({required this.block});

  final WorkoutBlock block;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, item) in block.items.indexed) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: Colors.white38,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${_positionLabel(block.format, index)}  ${item.exerciseName}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.block,
    required this.index,
    required this.item,
  });

  final WorkoutBlock block;
  final int index;
  final WorkoutItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 34),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x33FF8A50),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _positionLabel(block.format, index),
                style: const TextStyle(
                  color: Color(0xFFFFA06F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.exerciseName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _PrescriptionDetails(block: block, itemIndex: index, sets: item.sets),
        if (item.exerciseDescription case final description?) ...[
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, height: 1.3),
          ),
        ],
        if (item.notes case final notes?) ...[
          const SizedBox(height: 5),
          Text('Nota · $notes', style: const TextStyle(color: Colors.white60)),
        ],
      ],
    );
  }
}

class _PrescriptionDetails extends StatelessWidget {
  const _PrescriptionDetails({
    required this.block,
    required this.itemIndex,
    required this.sets,
  });

  final WorkoutBlock block;
  final int itemIndex;
  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) {
      return const Text(
        'Sin series prescritas',
        style: TextStyle(color: Colors.white54),
      );
    }

    if (_setsAreEquivalent(sets)) {
      final prefix = switch (block.format) {
        WorkoutBlockFormat.amrap => 'En cada vuelta',
        WorkoutBlockFormat.tabata => 'Trabajo',
        WorkoutBlockFormat.straightSets => '${sets.length} series',
        WorkoutBlockFormat.intervals => '${sets.length} intervalos',
        _ => '${sets.length} rondas',
      };
      return Text(
        '$prefix · ${_setPrescription(sets.first, block.format, includeRest: _includesSetRest(block, itemIndex))}',
        style: const TextStyle(
          color: Color(0xFFFFA06F),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (setIndex, set) in sets.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_setPositionLabel(block.format, setIndex)} · ${_setPrescription(set, block.format, includeRest: _includesSetRest(block, itemIndex))}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
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

String _blockFormatLabel(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.straightSets => 'Series convencionales',
  WorkoutBlockFormat.circuit => 'Circuito',
  WorkoutBlockFormat.superset => 'Superserie',
  WorkoutBlockFormat.intervals => 'Intervalos de trabajo',
  WorkoutBlockFormat.emom => 'EMOM',
  WorkoutBlockFormat.amrap => 'AMRAP',
  WorkoutBlockFormat.tabata => 'Tabata',
  WorkoutBlockFormat.warmUp => 'Calentamiento',
  WorkoutBlockFormat.coolDown => 'Vuelta a la calma',
};

String _blockPlanSummary(WorkoutBlock block) {
  final itemCount = block.items.length;
  final finalRest = block.restAfterSeconds > 0
      ? ' · ${_duration(block.restAfterSeconds)} entre rondas'
      : '';
  return switch (block.format) {
    WorkoutBlockFormat.straightSets =>
      '$itemCount ${itemCount == 1 ? 'ejercicio' : 'ejercicios'} · ${block.items.fold<int>(0, (total, item) => total + item.sets.length)} series',
    WorkoutBlockFormat.superset =>
      '${block.rounds} rondas · A1 y A2 seguidos$finalRest',
    WorkoutBlockFormat.circuit =>
      '${block.rounds} rondas · $itemCount estaciones$finalRest',
    WorkoutBlockFormat.intervals =>
      '${block.items.firstOrNull?.sets.length ?? 0} intervalos · ${_duration(block.restAfterSeconds)} de recuperación',
    WorkoutBlockFormat.tabata =>
      '8 intervalos · 20 s de trabajo / 10 s de recuperación',
    WorkoutBlockFormat.emom =>
      '${block.rounds * itemCount} min · $itemCount ${itemCount == 1 ? 'estación' : 'estaciones'} × ${block.rounds} vueltas',
    WorkoutBlockFormat.amrap =>
      '${_duration(block.timeCapSeconds ?? 0)} · todas las vueltas posibles',
    WorkoutBlockFormat.warmUp || WorkoutBlockFormat.coolDown =>
      '$itemCount ${itemCount == 1 ? 'ejercicio' : 'ejercicios'}',
  };
}

bool _showsSequence(WorkoutBlockFormat format) => switch (format) {
  WorkoutBlockFormat.superset ||
  WorkoutBlockFormat.circuit ||
  WorkoutBlockFormat.tabata ||
  WorkoutBlockFormat.emom ||
  WorkoutBlockFormat.amrap => true,
  _ => false,
};

String _positionLabel(WorkoutBlockFormat format, int index) => switch (format) {
  WorkoutBlockFormat.superset => 'A${index + 1}',
  WorkoutBlockFormat.circuit => 'E${index + 1}',
  WorkoutBlockFormat.tabata => 'I${index + 1}',
  WorkoutBlockFormat.emom => 'M${index + 1}',
  WorkoutBlockFormat.amrap => '${index + 1}',
  _ => '${index + 1}',
};

String _setPositionLabel(WorkoutBlockFormat format, int index) =>
    switch (format) {
      WorkoutBlockFormat.intervals => 'Intervalo ${index + 1}',
      WorkoutBlockFormat.straightSets => 'Serie ${index + 1}',
      _ => 'Ronda ${index + 1}',
    };

bool _setsAreEquivalent(List<WorkoutSet> sets) {
  final first = sets.first;
  return sets
      .skip(1)
      .every(
        (set) =>
            set.targetReps == first.targetReps &&
            set.targetDurationSeconds == first.targetDurationSeconds &&
            set.targetDistanceMeters == first.targetDistanceMeters &&
            set.targetLoadKg == first.targetLoadKg &&
            set.targetRpe == first.targetRpe &&
            set.targetRir == first.targetRir &&
            set.restAfterSeconds == first.restAfterSeconds,
      );
}

bool _includesSetRest(WorkoutBlock block, int itemIndex) =>
    block.format == WorkoutBlockFormat.straightSets ||
    block.format == WorkoutBlockFormat.warmUp ||
    block.format == WorkoutBlockFormat.coolDown ||
    (block.format == WorkoutBlockFormat.circuit &&
        itemIndex < block.items.length - 1);

String _setPrescription(
  WorkoutSet set,
  WorkoutBlockFormat format, {
  required bool includeRest,
}) {
  final parts = <String>[];
  final target = switch ((
    set.targetReps,
    set.targetDurationSeconds,
    set.targetDistanceMeters,
  )) {
    (final int reps, _, _) => '$reps repeticiones',
    (_, final int seconds, _) => '${_duration(seconds)} de trabajo',
    (_, _, final double meters) => '${_number(meters)} m',
    _ => 'objetivo configurado',
  };
  parts.add(target);
  if (set.targetLoadKg case final load?) {
    parts.add('${_number(load)} kg');
  }
  if (set.targetRir case final rir?) parts.add('RIR ${_number(rir)}');
  if (set.targetRpe case final rpe?) parts.add('RPE ${_number(rpe)}');
  if (includeRest && set.restAfterSeconds > 0) {
    final restName = format == WorkoutBlockFormat.circuit
        ? 'transición'
        : 'descanso';
    parts.add('${_duration(set.restAfterSeconds)} $restName');
  }
  return parts.join(' · ');
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
