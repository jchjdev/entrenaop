import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Evolución'),
      ),
      body: BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
        builder: (context, state) => switch (state.status) {
          WorkoutHistoryStatus.initial || WorkoutHistoryStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          WorkoutHistoryStatus.failure => _ErrorView(
            message: state.errorMessage!,
            onRetry: context.read<WorkoutHistoryCubit>().load,
          ),
          WorkoutHistoryStatus.loaded => _HistoryContent(
            executions: state.executions,
          ),
        },
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.executions});

  final List<WorkoutExecution> executions;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: context.read<WorkoutHistoryCubit>().load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tus entrenamientos',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Consulta lo prescrito y lo que realizaste realmente.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/assessment/history/physical'),
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Ver evaluaciones físicas'),
                  ),
                  const SizedBox(height: 24),
                  if (executions.isEmpty)
                    const _EmptyHistory()
                  else
                    ...executions.map(_WorkoutHistoryCard.new),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  const _WorkoutHistoryCard(this.execution);

  final WorkoutExecution execution;

  @override
  Widget build(BuildContext context) {
    final abandoned = execution.status == WorkoutExecutionStatus.abandoned;
    final completedAt = execution.completedAt;
    final duration = completedAt?.difference(execution.startedAt);
    return Card(
      color: const Color(0xFF171717),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/assessment/history/workouts/${execution.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      execution.templateName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusChip(abandoned: abandoned),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _dateFormat.format(execution.startedAt.toLocal()),
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Metric(
                    icon: Icons.check_circle_outline_rounded,
                    text: '${execution.completedSetCount} completadas',
                  ),
                  if (execution.skippedSetCount > 0)
                    _Metric(
                      icon: Icons.skip_next_rounded,
                      text: '${execution.skippedSetCount} omitidas',
                    ),
                  if (duration != null)
                    _Metric(
                      icon: Icons.schedule_rounded,
                      text: _formatDuration(duration),
                    ),
                  if (execution.finalRpe case final rpe?)
                    _Metric(icon: Icons.speed_rounded, text: 'RPE $rpe'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.abandoned});

  final bool abandoned;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        abandoned ? Icons.flag_outlined : Icons.check_rounded,
        size: 16,
      ),
      label: Text(abandoned ? 'Cerrada' : 'Completada'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFFFF8A50)),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFF171717),
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 44, color: Color(0xFFFF8A50)),
            SizedBox(height: 12),
            Text(
              'Aún no hay sesiones terminadas',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Las sesiones completadas o cerradas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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

final _dateFormat = DateFormat('dd/MM/yyyy · HH:mm');

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours h' : '$hours h $remainder min';
}
