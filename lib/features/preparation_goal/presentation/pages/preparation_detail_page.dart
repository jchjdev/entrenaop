import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_week_prototype_card.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PreparationDetailPage extends StatelessWidget {
  const PreparationDetailPage({super.key});

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
        title: const Text('Preparación'),
      ),
      body: BlocConsumer<PreparationDetailCubit, PreparationDetailState>(
        listener: (context, state) {
          final message = state.errorMessage;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          if (state.detail == null &&
              state.status == PreparationDetailStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.detail == null) {
            return _Failure(
              onRetry: context.read<PreparationDetailCubit>().load,
            );
          }
          return _Content(state: state);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final PreparationDetailState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    final goal = detail.goal;
    return RefreshIndicator(
      onRefresh: context.read<PreparationDetailCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status == PreparationDetailStatus.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                  Text(
                    goal.program.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    goal.targetDate == null
                        ? 'Sin fecha objetivo'
                        : 'Objetivo: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                    style: const TextStyle(
                      color: Color(0xFFFFA477),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: const Color(0xFF171717),
                    child: ListTile(
                      leading: const Icon(
                        Icons.directions_run,
                        color: Color(0xFFFF8A50),
                      ),
                      title: const Text('Control de carrera · 2 km'),
                      subtitle: const Text(
                        'Registra una marca nueva o consulta los tests anteriores de esta preparación.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/plan/goal/${goal.id}/running-test'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AssessmentCard(state: state),
                  if (goal.programId ==
                      PreparationProgramIds.armedForcesTroopEntry) ...[
                    const SizedBox(height: 12),
                    const RunningWeekPrototypeCard(),
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFF211B18),
                      child: ListTile(
                        leading: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFFFFA477),
                        ),
                        title: const Text('Simular primera semana'),
                        subtitle: const Text(
                          'Prueba escenarios sin guardar ni asignar entrenamientos.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/plan/goal/${goal.id}/week-simulator',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _WeekHeader(state: state),
                  const SizedBox(height: 12),
                  if (detail.weeklyWorkouts.isEmpty)
                    const _EmptyWeek()
                  else
                    ...detail.weeklyWorkouts.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WorkoutCard(item: item),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/plan/week'),
                    icon: const Icon(Icons.calendar_view_week_outlined),
                    label: const Text('Ver agenda completa'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'EntrenaOP asignará aquí las sesiones oficiales. Tus sesiones libres siguen separadas en la agenda general.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.state});

  final PreparationDetailState state;

  @override
  Widget build(BuildContext context) {
    final assessment = state.detail!.latestAssessment;
    return Card(
      color: const Color(0xFF171717),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: Color(0xFFFF8A50)),
                SizedBox(width: 10),
                Text(
                  'Últimas marcas compatibles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (assessment == null) ...[
              const Text(
                'Todavía no hay una evaluación compatible con esta preparación.',
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/assessment/initial'),
                child: const Text('Registrar evaluación'),
              ),
            ] else ...[
              Text(
                formatAssessmentDate(assessment.completedAt),
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 10),
              for (final result in assessment.report.results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(child: Text(result.standard.test.name)),
                      Text(
                        formatAssessmentValue(
                          result.mark.value,
                          result.standard.test,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.state});
  final PreparationDetailState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Semana anterior',
          onPressed: () =>
              context.read<PreparationDetailCubit>().changeWeek(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'SEMANA DE ESTA PREPARACIÓN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF8A50),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateFormat('dd/MM').format(state.weekStart)} – ${DateFormat('dd/MM').format(state.weekEnd)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Semana siguiente',
          onPressed: () => context.read<PreparationDetailCubit>().changeWeek(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.item});
  final ScheduledWorkout item;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151515),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF29150D),
          foregroundColor: const Color(0xFFFF8A50),
          child: Text('${item.scheduledDate.day}'),
        ),
        title: Text(item.templateName),
        subtitle: Text(
          '${_sourceLabel(item.source)} · v${item.templateVersion} · ${_statusLabel(item.status)}',
        ),
        trailing: item.estimatedDurationMinutes == null
            ? null
            : Text('${item.estimatedDurationMinutes} min'),
      ),
    );
  }
}

class _EmptyWeek extends StatelessWidget {
  const _EmptyWeek();

  @override
  Widget build(BuildContext context) => const Card(
    color: Color(0xFF151515),
    child: Padding(
      padding: EdgeInsets.all(22),
      child: Text(
        'EntrenaOP todavía no ha pautado sesiones oficiales para esta semana.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60),
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Reintentar'),
    ),
  );
}

String _sourceLabel(ScheduledWorkoutSource source) => switch (source) {
  ScheduledWorkoutSource.library => 'EntrenaOP',
  ScheduledWorkoutSource.user => 'Personal',
  ScheduledWorkoutSource.preparation => 'Preparación',
  ScheduledWorkoutSource.algorithm => 'Adaptativa',
  ScheduledWorkoutSource.coach => 'Entrenador',
};

String _statusLabel(ScheduledWorkoutStatus status) => switch (status) {
  ScheduledWorkoutStatus.planned => 'Pendiente',
  ScheduledWorkoutStatus.inProgress => 'En curso',
  ScheduledWorkoutStatus.completed => 'Completada',
  ScheduledWorkoutStatus.abandoned => 'Abandonada',
  ScheduledWorkoutStatus.skipped => 'Omitida',
};
