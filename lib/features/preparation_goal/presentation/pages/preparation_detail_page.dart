import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/pro/domain/pro_offer.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_discovery_card.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PreparationDetailPage extends StatelessWidget {
  const PreparationDetailPage({
    super.key,
    this.hasRunningContext,
    this.saveTargetDate,
  });

  final Future<bool> Function(String goalId, String programId)?
  hasRunningContext;
  final Future<void> Function(PreparationGoal goal, DateTime date)?
  saveTargetDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          return _Content(
            state: state,
            hasRunningContext: hasRunningContext,
            saveTargetDate: saveTargetDate,
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.hasRunningContext,
    required this.saveTargetDate,
  });

  final PreparationDetailState state;
  final Future<bool> Function(String goalId, String programId)?
  hasRunningContext;
  final Future<void> Function(PreparationGoal goal, DateTime date)?
  saveTargetDate;

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
                  if (goal.id != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: const Text('Programa de entrenamiento'),
                        subtitle: const Text(
                          'Configura o revisa tus objetivos, punto de partida y propuesta de entrenamiento.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push('/plan/goal/${goal.id}/training');
                          if (context.mounted) {
                            context.read<PreparationDetailCubit>().load();
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  EntrenaCard(
                    coverImage: preparationCoverProvider(
                      goal.program.cover?.headerUrl,
                    ),
                    focalX: goal.program.cover?.headerFocalX ?? 0.5,
                    focalY: goal.program.cover?.headerFocalY ?? 0.5,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: goal.program.cover == null ? 0 : 32,
                      ),
                      child: Text(
                        goal.program.name,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: saveTargetDate == null
                        ? null
                        : () => _changeTargetDate(context, goal),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      goal.targetDate == null
                          ? 'Añadir fecha objetivo'
                          : 'Objetivo: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)} · Cambiar',
                    ),
                  ),
                  if (goal.targetDate != null &&
                      (goal.programId ==
                              PreparationProgramIds.armedForcesTroopEntry ||
                          goal.programId ==
                              PreparationProgramIds.fasPeriodicAssessment ||
                          detail.runningReferenceCandidates.isNotEmpty) &&
                      goal.targetDate!.isAfter(
                        DateUtils.dateOnly(DateTime.now())
                            .add(const Duration(days: 365)),
                      ))
                    const Text(
                      'Objetivo a largo plazo: la fecha se conserva, pero el plan de carrera se revisa semana a semana con tus datos actuales.',
                    ),
                  const SizedBox(height: 22),
                  if (goal.id != null &&
                      (goal.programId ==
                              PreparationProgramIds.armedForcesTroopEntry ||
                          goal.programId ==
                              PreparationProgramIds.fasPeriodicAssessment)) ...[
                    ProDiscoveryCard(
                      offerContext: ProOfferContext(
                        goalId: goal.id,
                        preparationName: goal.program.name,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  if (goal.programId !=
                          PreparationProgramIds.fasPeriodicAssessment &&
                      goal.program.currentAssessmentCatalogVersion == null &&
                      goal.id != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.fact_check_outlined,
                          color: Color(0xFFFF8A50),
                        ),
                        title: const Text('Evaluación de esta preparación'),
                        subtitle: const Text(
                          'Registra tus marcas, consulta el baremo aplicable y revisa tus resultados.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push(
                            '/plan/goal/${goal.id}/program-assessment',
                          );
                          if (context.mounted) {
                            context.read<PreparationDetailCubit>().load();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (goal.programId !=
                          PreparationProgramIds.armedForcesTroopEntry &&
                      goal.programId !=
                          PreparationProgramIds.fasPeriodicAssessment &&
                      detail.runningReferenceCandidates.isNotEmpty) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.directions_run,
                          color: Color(0xFFFF8A50),
                        ),
                        title: const Text('Marca de carrera · 2 km'),
                        subtitle: Text(
                          'De tu evaluación de este programa: ${_formatRunningSeconds(detail.runningReferenceCandidates.first.durationSeconds)} · ${DateFormat('dd/MM/yyyy').format(detail.runningReferenceCandidates.first.completedAt)}. Aún no genera entrenamientos.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push(
                            '/plan/goal/${goal.id}/program-assessment',
                          );
                          if (context.mounted) {
                            context.read<PreparationDetailCubit>().load();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (goal.programId ==
                      PreparationProgramIds.fasPeriodicAssessment) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.monitor_heart_outlined,
                          color: Color(0xFFFF8A50),
                        ),
                        title: const Text('Marcas para Mejora FAS'),
                        subtitle: const Text(
                          'Consulta tus tests FAS guardados en el perfil y elige cuál usar en esta preparación.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/plan/goal/${goal.id}/periodic-assessment',
                        ),
                      ),
                    ),
                  ] else if (goal.programId ==
                      PreparationProgramIds.armedForcesTroopEntry) ...[
                    _TroopAssessmentCard(
                      goalId: goal.id!,
                      assessment: detail.latestTroopAssessment,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.directions_run,
                          color: Color(0xFFFF8A50),
                        ),
                        title: const Text('Control específico · 2 km'),
                        subtitle: Text(
                          detail.latestRunningTest == null
                              ? 'Todavía no hay una marca de 2 km guardada en esta preparación.'
                              : 'Última marca: ${detail.latestRunningTest!.durationSeconds ~/ 60}:${(detail.latestRunningTest!.durationSeconds % 60).toString().padLeft(2, '0')} · ${DateFormat('dd/MM/yyyy').format(detail.latestRunningTest!.completedAt)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push(
                            '/plan/goal/${goal.id}/running-test',
                          );
                          if (context.mounted) {
                            context.read<PreparationDetailCubit>().load();
                          }
                        },
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTargetDate(
    BuildContext context,
    PreparationGoal goal,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: goal.targetDate?.isAfter(today) == true
          ? goal.targetDate!
          : today.add(const Duration(days: 90)),
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      helpText: 'Fecha prevista de las pruebas',
    );
    if (selected == null || !context.mounted) return;
    try {
      await saveTargetDate!(goal, selected);
      if (context.mounted) context.read<PreparationDetailCubit>().load();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hemos podido guardar la fecha.')),
        );
      }
    }
  }
}

class _TroopAssessmentCard extends StatelessWidget {
  const _TroopAssessmentCard({required this.goalId, required this.assessment});

  final String goalId;
  final PhysicalAssessmentHistoryEntry? assessment;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pruebas de ingreso · Tropa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (assessment == null)
            const Text(
              'Aún no has registrado las cuatro marcas en esta preparación.',
            )
          else ...[
            Text(formatAssessmentDate(assessment!.completedAt)),
            const SizedBox(height: 8),
            for (final result in assessment!.report.results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await context.push('/plan/goal/$goalId/troop-assessment');
                if (context.mounted) {
                  context.read<PreparationDetailCubit>().load();
                }
              },
              child: Text(
                assessment == null
                    ? 'Registrar marcas'
                    : 'Registrar nuevas marcas',
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
            ? const Icon(Icons.chevron_right_rounded)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${item.estimatedDurationMinutes} min'),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
        onTap: () async {
          final executionId = item.executionId;
          final destination = switch (item.status) {
            ScheduledWorkoutStatus.completed || ScheduledWorkoutStatus.abandoned
                when executionId != null =>
              '/assessment/history/workouts/$executionId',
            ScheduledWorkoutStatus.inProgress when executionId != null =>
              '/plan/week/active/$executionId',
            _ =>
              '/plan/week?date=${DateFormat('yyyy-MM-dd').format(item.scheduledDate)}',
          };
          await context.push(destination);
          if (context.mounted) {
            context.read<PreparationDetailCubit>().load();
          }
        },
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
        'No hay sesiones pautadas para esta semana. Usa las flechas para consultar otras semanas.',
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

String _formatRunningSeconds(double value) {
  final minutes = value ~/ 60;
  final seconds = value - minutes * 60;
  final raw = seconds.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
  final clean = raw.endsWith('.') ? raw.substring(0, raw.length - 1) : raw;
  final parts = clean.split('.');
  final whole = parts.first.padLeft(2, '0');
  return '$minutes:$whole${parts.length == 1 ? '' : '.${parts.last}'}';
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
