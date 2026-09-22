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
        builder: (context, state) => _HistoryContent(state: state),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.state});

  final WorkoutHistoryState state;

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
                    'Tu evolución, en contexto',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Consulta tus controles físicos y lo que has realizado en cada entrenamiento.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Evaluaciones y controles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _DestinationCard(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Evaluación física · Tropa',
                    subtitle:
                        'Consulta tus marcas y repite las pruebas de esta evaluación.',
                    onTap: () => context.push('/assessment/history/physical'),
                  ),
                  const SizedBox(height: 8),
                  _DestinationCard(
                    icon: Icons.flag_outlined,
                    title: 'Controles por preparación',
                    subtitle:
                        'Abre un programa para ver o repetir sus tests, como el de 2 km.',
                    onTap: () => context.push('/plan/goal'),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Historial de entrenamientos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (state.status == WorkoutHistoryStatus.loaded)
                        Text(
                          '${state.executions.length}',
                          style: const TextStyle(
                            color: Color(0xFFFFA477),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Objetivo previsto y resultado real de cada sesión.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  if (state.status == WorkoutHistoryStatus.initial ||
                      state.status == WorkoutHistoryStatus.loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == WorkoutHistoryStatus.failure)
                    _ErrorView(
                      message: state.errorMessage!,
                      onRetry: context.read<WorkoutHistoryCubit>().load,
                    )
                  else if (state.executions.isEmpty)
                    const _EmptyHistory()
                  else
                    ...state.executions.map(_WorkoutHistoryCard.new),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF171717),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF352016),
        foregroundColor: const Color(0xFFFFA477),
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
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
