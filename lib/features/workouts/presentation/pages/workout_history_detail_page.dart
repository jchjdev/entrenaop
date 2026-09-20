import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryDetailPage extends StatelessWidget {
  const WorkoutHistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Detalle de la sesión'),
      ),
      body: BlocBuilder<WorkoutHistoryDetailCubit, WorkoutHistoryDetailState>(
        builder: (context, state) => switch (state.status) {
          WorkoutHistoryDetailStatus.initial ||
          WorkoutHistoryDetailStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          WorkoutHistoryDetailStatus.failure => _DetailError(
            message: state.errorMessage!,
            onRetry: context.read<WorkoutHistoryDetailCubit>().load,
          ),
          WorkoutHistoryDetailStatus.loaded => _DetailContent(
            execution: state.execution!,
          ),
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.execution});

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    final groups = _groupSets(execution.sets);
    final abandoned = execution.status == WorkoutExecutionStatus.abandoned;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  execution.templateName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _dateFormat.format(execution.startedAt.toLocal()),
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 18),
                _SummaryCard(execution: execution),
                if (execution.notes case final notes?) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF171717),
                    child: ListTile(
                      leading: const Icon(
                        Icons.notes_rounded,
                        color: Color(0xFFFFA06F),
                      ),
                      title: const Text('Sensaciones de la sesión'),
                      subtitle: Text(notes),
                    ),
                  ),
                ],
                if (abandoned && execution.abandonmentReason != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF21130E),
                    child: ListTile(
                      leading: const Icon(
                        Icons.flag_outlined,
                        color: Color(0xFFFFA06F),
                      ),
                      title: const Text('Sesión cerrada antes de terminar'),
                      subtitle: Text(
                        _reasonLabel(execution.abandonmentReason!),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Objetivo y resultado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...groups.map(_ExerciseResultCard.new),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.execution});

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    final completedAt = execution.completedAt;
    final duration = completedAt?.difference(execution.startedAt);
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 22,
          runSpacing: 14,
          children: [
            _SummaryMetric(
              value: '${execution.completedSetCount}',
              label: 'Completadas',
            ),
            _SummaryMetric(
              value: '${execution.skippedSetCount}',
              label: 'Omitidas',
            ),
            _SummaryMetric(
              value: '${execution.sets.length - execution.resolvedSetCount}',
              label: 'Pendientes',
            ),
            if (duration != null)
              _SummaryMetric(
                value: _compactDuration(duration),
                label: 'Duración',
              ),
            if (execution.finalRpe case final rpe?)
              _SummaryMetric(value: '$rpe/10', label: 'RPE final'),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 105,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFA06F),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _ExerciseResultCard extends StatelessWidget {
  const _ExerciseResultCard(this.group);

  final _ExerciseGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171717),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              group.blockName.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFF8A50),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              group.exerciseName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...group.sets.map(_SetResultRow.new),
          ],
        ),
      ),
    );
  }
}

class _SetResultRow extends StatelessWidget {
  const _SetResultRow(this.set);

  final WorkoutExecutionSet set;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (set.status) {
      WorkoutSetStatus.completed => Colors.greenAccent,
      WorkoutSetStatus.skipped => Colors.orangeAccent,
      WorkoutSetStatus.pending => Colors.white38,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.15),
            ),
            child: Text('${set.setOrder + 1}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Objetivo · ${_target(set)}'),
                const SizedBox(height: 3),
                Text(_result(set), style: TextStyle(color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

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

class _ExerciseGroup {
  const _ExerciseGroup({
    required this.blockName,
    required this.exerciseName,
    required this.sets,
  });

  final String blockName;
  final String exerciseName;
  final List<WorkoutExecutionSet> sets;
}

List<_ExerciseGroup> _groupSets(List<WorkoutExecutionSet> sets) {
  final groups = <_ExerciseGroup>[];
  for (final set in sets) {
    final last = groups.isEmpty ? null : groups.last;
    if (last != null &&
        last.sets.first.exerciseId == set.exerciseId &&
        last.sets.first.itemOrder == set.itemOrder &&
        last.sets.first.blockOrder == set.blockOrder) {
      last.sets.add(set);
    } else {
      groups.add(
        _ExerciseGroup(
          blockName: set.blockName,
          exerciseName: set.exerciseName,
          sets: [set],
        ),
      );
    }
  }
  return groups;
}

String _target(WorkoutExecutionSet set) {
  final parts = <String>[];
  if (set.targetReps != null) parts.add('${set.targetReps} rep');
  if (set.targetDurationSeconds != null) {
    parts.add('${set.targetDurationSeconds} s');
  }
  if (set.targetDistanceMeters != null) {
    parts.add('${_number(set.targetDistanceMeters!)} m');
  }
  if (set.targetLoadKg != null) parts.add('${_number(set.targetLoadKg!)} kg');
  if (set.targetRir != null) parts.add('RIR ${_number(set.targetRir!)}');
  return parts.join(' · ');
}

String _result(WorkoutExecutionSet set) {
  if (set.status == WorkoutSetStatus.skipped) return 'Serie omitida';
  if (set.status == WorkoutSetStatus.pending) return 'No realizada';
  final parts = <String>[];
  if (set.actualReps != null) parts.add('${set.actualReps} rep');
  if (set.actualDurationSeconds != null) {
    parts.add('${set.actualDurationSeconds} s');
  }
  if (set.actualDistanceMeters != null) {
    parts.add('${_number(set.actualDistanceMeters!)} m');
  }
  if (set.actualLoadKg != null) parts.add('${_number(set.actualLoadKg!)} kg');
  if (set.actualRir != null) parts.add('RIR ${_number(set.actualRir!)}');
  return 'Realizado · ${parts.join(' · ')}';
}

String _reasonLabel(WorkoutAbandonmentReason reason) => switch (reason) {
  WorkoutAbandonmentReason.lackOfTime => 'Falta de tiempo',
  WorkoutAbandonmentReason.tooDifficult => 'Demasiada dificultad',
  WorkoutAbandonmentReason.discomfort => 'Molestias',
  WorkoutAbandonmentReason.other => 'Otro motivo',
};

String _compactDuration(Duration duration) {
  if (duration.inMinutes < 1) return '<1 min';
  if (duration.inHours < 1) return '${duration.inMinutes} min';
  final minutes = duration.inMinutes.remainder(60);
  return minutes == 0
      ? '${duration.inHours} h'
      : '${duration.inHours} h $minutes min';
}

String _number(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

final _dateFormat = DateFormat('dd/MM/yyyy · HH:mm');
