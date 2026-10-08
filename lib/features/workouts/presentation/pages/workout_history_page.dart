import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_history_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key, this.loadPreparations});

  final Future<List<PreparationGoal>> Function()? loadPreparations;

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  late Future<List<PreparationGoal>> _preparations = _loadPreparations();

  Future<List<PreparationGoal>> _loadPreparations() =>
      widget.loadPreparations?.call() ?? Future.value(const []);

  void _reloadPreparations() {
    final future = _loadPreparations();
    setState(() {
      _preparations = future;
    });
  }

  Future<void> _refresh() async {
    _reloadPreparations();
    await context.read<WorkoutHistoryCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return SectionRefreshBoundary(
      location: '/assessment/history',
      onVisible: () => _refresh(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Evolución'),
        ),
        body: BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
          builder: (context, state) => _HistoryContent(
            state: state,
            preparations: _preparations,
            onRefresh: _refresh,
            onRetryPreparations: _reloadPreparations,
          ),
        ),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.state,
    required this.preparations,
    required this.onRefresh,
    required this.onRetryPreparations,
  });

  final WorkoutHistoryState state;
  final Future<List<PreparationGoal>> preparations;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryPreparations;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey('evolution-history-scroll'),
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
                  if (state.isRefreshing) const LinearProgressIndicator(),
                  if (state.errorMessage != null && state.executions.isNotEmpty)
                    TextButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(state.errorMessage!),
                    ),
                  if (state.status == WorkoutHistoryStatus.loaded) ...[
                    _ActivitySummary(executions: state.executions),
                    const SizedBox(height: 24),
                  ],
                  const Text(
                    'Evaluaciones y controles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<PreparationGoal>>(
                    future: preparations,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return TextButton.icon(
                          onPressed: onRetryPreparations,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Reintentar cargar tus preparaciones',
                          ),
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LinearProgressIndicator();
                      }
                      final goals = snapshot.data ?? const <PreparationGoal>[];
                      return Column(
                        children: [
                          for (final goal in goals.where((g) => g.id != null))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DestinationCard(
                                icon: Icons.flag_outlined,
                                title: 'Marcas · ${goal.program.name}',
                                subtitle: 'Evaluación y resultados de esta preparación.',
                                onTap: () => context.push(
                                  '/assessment/history/preparations/${goal.id}',
                                ),
                              ),
                            ),
                          if (goals.isEmpty)
                            _DestinationCard(
                              icon: Icons.flag_outlined,
                              title: 'Tus preparaciones',
                              subtitle: 'Añade una preparación para consultar sus marcas aquí.',
                              onTap: () => context.push('/plan/goal'),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _DestinationCard(
                    icon: Icons.military_tech_outlined,
                    title: 'Pruebas FAS personales',
                    subtitle: 'Tus tests guardados, aunque no pertenezcan a ninguna preparación.',
                    onTap: () => context.push('/assessment/fas-history'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Otros historiales'),
                    children: [
                      _DestinationCard(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Historial físico · Tropa',
                        subtitle: 'Consulta las evaluaciones anteriores que hayas guardado.',
                        onTap: () =>
                            context.push('/assessment/history/physical'),
                      ),
                    ],
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
                          '${state.executions.length} cargadas',
                          style: const TextStyle(
                            color: Color(0xFFFFA477),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
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
                  FutureBuilder<List<PreparationGoal>>(
                    future: preparations,
                    builder: (context, snapshot) => WorkoutHistoryFilters(
                      query: state.query,
                      goals: snapshot.data ?? const [],
                      onChanged: context.read<WorkoutHistoryCubit>().filter,
                    ),
                  ),
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
                    state.query.hasFilters
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No hay sesiones que coincidan con estos filtros.',
                            ),
                          )
                        : const _EmptyHistory()
                  else ...[
                    ...state.executions.map(_WorkoutHistoryCard.new),
                    if (state.moreError != null) Text(state.moreError!),
                    if (state.hasMore)
                      OutlinedButton.icon(
                        onPressed: state.isLoadingMore || state.isRefreshing
                            ? null
                            : context.read<WorkoutHistoryCubit>().loadMore,
                        icon: const Icon(Icons.history_rounded),
                        label: Text(
                          state.isLoadingMore
                              ? 'Cargando…'
                              : state.moreError != null
                              ? 'Reintentar cargar más'
                              : 'Cargar más sesiones',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.executions});
  final List<WorkoutExecution> executions;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final end = today.add(const Duration(days: 1));
    final recent = executions
        .where(
          (e) =>
              e.status == WorkoutExecutionStatus.completed &&
              e.completedAt != null &&
              !e.completedAt!.toLocal().isBefore(start) &&
              e.completedAt!.toLocal().isBefore(end),
        )
        .toList();
    final days = recent
        .map((e) => DateUtils.dateOnly(e.completedAt!.toLocal()))
        .toSet()
        .length;
    return EntrenaCard(
      tone: EntrenaCardTone.progress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu actividad reciente',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${recent.length} sesiones completadas · $days días con entrenamiento',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Últimos 7 días dentro del historial consultado. Los filtros delimitan esta consulta; las sesiones incompletas siguen en el detalle.',
            style: TextStyle(color: context.visuals.textMuted, fontSize: 13),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Text(
                    execution.templateName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(18) > 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        _StatusChip(abandoned: abandoned),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      _StatusChip(abandoned: abandoned),
                    ],
                  );
                },
              ),
              const SizedBox(height: 7),
              Text(
                '${execution.sessionType.label} · ${_dateFormat.format(execution.startedAt.toLocal())}',
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
        Flexible(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
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
