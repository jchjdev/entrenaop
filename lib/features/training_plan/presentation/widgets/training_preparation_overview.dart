import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/images/editorial_cover_provider.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../../core/theme/entrena_theme.dart';
import '../../../dashboard/domain/entities/preparation_overview.dart';
import '../../../dashboard/presentation/home_day_selection.dart';
import '../../../dashboard/presentation/widgets/preparation_status_label.dart';
import '../../../pro/presentation/widgets/pro_access_widgets.dart';
import '../../../workout_schedule/domain/entities/scheduled_workout.dart';

/// Composición del resumen existente: no elige otra preparación ni calcula dosis.
class TrainingPreparationOverview extends StatelessWidget {
  const TrainingPreparationOverview({
    required this.overview,
    this.loadProAccess,
    super.key,
  });
  final PreparationOverview overview;
  final LoadProAccess? loadProAccess;

  @override
  Widget build(BuildContext context) {
    final program =
        overview.activeProgram ??
        (overview.goals.isEmpty
            ? overview.programs.where((p) => p.status == 'complete').firstOrNull
            : overview.programs
                  .where((p) => p.goalId == overview.goals.first.id)
                  .firstOrNull);
    final goal = program == null
        ? overview.goals.firstOrNull
        : overview.goals.where((g) => g.id == program.goalId).firstOrNull;
    final goalId = program?.goalId ?? goal?.id;
    final workouts =
        overview.weeklyWorkouts
            .where(
              (w) =>
                  w.preparationGoalId == goalId &&
                  w.source == ScheduledWorkoutSource.algorithm,
            )
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final next =
        workouts
            .where((w) => w.status == ScheduledWorkoutStatus.inProgress)
            .firstOrNull ??
        workouts
            .where((w) => w.status == ScheduledWorkoutStatus.planned)
            .firstOrNull;
    final resolved = workouts
        .where(
          (w) =>
              w.status != ScheduledWorkoutStatus.planned &&
              w.status != ScheduledWorkoutStatus.inProgress,
        )
        .length;
    final hasPlan = program?.isStarted == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntrenaCard(
          tone: EntrenaCardTone.accent,
          coverImage: editorialCoverProvider(goal?.program.cover?.headerUrl),
          focalX: goal?.program.cover?.headerFocalX ?? 0.5,
          focalY: goal?.program.cover?.headerFocalY ?? 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'TU PREPARACIÓN',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (goalId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            program?.proRequired == true
                                ? Icons.bookmark_outline_rounded
                                : program?.isPaused == true
                                ? Icons.pause_rounded
                                : program?.needsReview == true
                                ? Icons.info_outline_rounded
                                : program?.isCurrent == true
                                ? Icons.check_rounded
                                : Icons.flag_outlined,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(preparationStatusLabel(program)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                goal?.program.name ?? program?.name ?? 'Tu próxima preparación',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (goal?.targetDate case final date?) ...[
                const SizedBox(height: 12),
                Text('Objetivo · ${DateFormat('dd-MM-yyyy').format(date)}'),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Tu plan adaptativo',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                hasPlan
                    ? program!.proRequired
                          ? 'Puedes consultar tus entrenamientos y resultados. Activa Pro para empezar nuevas sesiones del plan.'
                          : program.isPaused
                          ? 'Tu objetivo, tu plan y tus resultados siguen aquí. Puedes consultarlos antes de retomarlo.'
                          : program.message
                    : goalId == null
                    ? 'Elige para qué quieres prepararte. Tu plan tendrá en cuenta tus marcas, disponibilidad y resultados.'
                    : 'Revisa tu punto de partida y la propuesta antes de activar tu plan.',
                style: TextStyle(color: context.visuals.textMuted),
              ),
              if (program?.isCurrent == true && workouts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Semana del ${DateFormat('dd/MM').format(overview.weekStart)} · $resolved de ${workouts.length} resueltas',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: resolved / workouts.length,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
              const SizedBox(height: 20),
              if (hasPlan)
                FilledButton.icon(
                  iconAlignment: IconAlignment.end,
                  onPressed: () => context.push('/plan/goal/$goalId/plan'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    program!.proRequired ||
                            program.isPaused ||
                            program.status == 'complete'
                        ? 'Consultar mi plan'
                        : 'Ver mi plan',
                  ),
                )
              else if (goalId == null) ...[
                FilledButton.icon(
                  onPressed: () => context.push('/plan/goal'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Elegir preparación'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El plan adaptativo requiere Pro. Elegir tu preparación no lo activa.',
                ),
              ] else
                _PlanAction(
                  goalId: goalId,
                  load: loadProAccess,
                  label: 'Configurar mi plan',
                  primary: true,
                ),
              if (program?.proRequired == true ||
                  program?.isPaused == true ||
                  program?.needsReview == true) ...[
                const SizedBox(height: 8),
                _PlanAction(
                  goalId: goalId!,
                  load: loadProAccess,
                  label: program!.proRequired || program.isPaused
                      ? 'Retomar'
                      : 'Revisar lo pendiente',
                ),
              ],
            ],
          ),
        ),
        if (next != null &&
            ((program?.isCurrent == true && program?.proRequired != true) ||
                (program?.proRequired == true &&
                    next.status == ScheduledWorkoutStatus.inProgress))) ...[
          const SizedBox(height: 20),
          EntrenaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  next.status == ScheduledWorkoutStatus.inProgress
                      ? 'ENTRENAMIENTO EN CURSO'
                      : 'PRÓXIMO ENTRENAMIENTO',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  next.templateName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('dd/MM').format(next.scheduledDate)} · ${next.estimatedDurationMinutes == null ? 'Plan adaptativo' : '${next.estimatedDurationMinutes} min · Plan adaptativo'}',
                ),
                const SizedBox(height: 12),
                Text(
                  program?.proRequired == true
                      ? next.status == ScheduledWorkoutStatus.inProgress
                            ? 'Puedes continuar y terminar este entrenamiento ya iniciado.'
                            : 'Puedes consultar lo pautado. Empezar otro entrenamiento adaptativo requiere Pro.'
                      : 'Consulta lo pautado antes de comenzar.',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.push(
                    '/plan/week/session/${Uri.encodeComponent(next.id)}?date=${homeDateParam(next.scheduledDate)}',
                  ),
                  child: const Text('Ver entrenamiento'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open_rounded),
          title: const Text('Gestionar preparaciones'),
          subtitle: const Text('Objetivos guardados y configuración'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/plan/preparations'),
        ),
        if (overview.weeklyWorkouts.any(
          (w) => w.source == ScheduledWorkoutSource.coach,
        )) ...[
          const SizedBox(height: 12),
          Text(
            'Las sesiones de tu preparador están disponibles en tu semana.',
            style: TextStyle(color: context.visuals.textMuted),
          ),
        ],
      ],
    );
  }
}

class _PlanAction extends StatelessWidget {
  const _PlanAction({
    required this.goalId,
    required this.label,
    required this.load,
    this.primary = false,
  });
  final String goalId, label;
  final LoadProAccess? load;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    Widget action(bool? isPro) {
      final text = '$label${isPro == false ? ' · Pro' : ''}';
      void open() => context.push('/plan/goal/$goalId/training');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primary)
            FilledButton(onPressed: open, child: Text(text))
          else
            TextButton(onPressed: open, child: Text(text)),
          if (isPro != true)
            const Text('Activar o retomar el plan adaptativo requiere Pro.'),
        ],
      );
    }

    return load == null
        ? action(null)
        : ProAccessBuilder(
            load: load!,
            builder: (_, access) => action(access.isPro),
          );
  }
}
