import '../widgets/training_equipment_labels.dart';

import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/dashboard/presentation/home_day_selection.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/preparation_status_label.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Una URL directa de preparación no necesita cargar el resumen de su raíz.
/// Tras visitarla se conserva el Cubit al abrir sus rutas hijas.
class TrainingHubEntry extends StatefulWidget {
  const TrainingHubEntry({required this.createCubit, super.key});
  final DashboardCubit Function() createCubit;

  @override
  State<TrainingHubEntry> createState() => _TrainingHubEntryState();
}

class _TrainingHubEntryState extends State<TrainingHubEntry> {
  GoRouter? _router;
  bool _visited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router == router) return;
    _router?.routerDelegate.removeListener(_routeChanged);
    _router = router;
    _visited = _visited || router.state.uri.path == '/plan';
    router.routerDelegate.addListener(_routeChanged);
  }

  void _routeChanged() {
    if (!_visited && _router?.state.uri.path == '/plan') {
      setState(() => _visited = true);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visited
      ? BlocProvider(
          create: (_) => widget.createCubit(),
          child: const TrainingHubPage(),
        )
      : const SizedBox.shrink();
}

/// Resumen del programa y de sesiones ya asignadas; no prescribe entrenamiento.
class TrainingHubPage extends StatelessWidget {
  const TrainingHubPage({super.key});

  @override
  Widget build(BuildContext context) => SectionRefreshBoundary(
    location: '/plan',
    onVisible: context.read<DashboardCubit>().load,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mi plan'),
        actions: [
          IconButton(
            tooltip: 'Actualizar mi plan',
            onPressed: context.read<DashboardCubit>().load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            final overview = state.overview;
            if (overview == null && state.status != DashboardStatus.failure) {
              return const Center(child: CircularProgressIndicator());
            }
            if (overview == null) {
              return Center(
                child: _LoadFailure(
                  onRetry: context.read<DashboardCubit>().load,
                ),
              );
            }
            return _PlanContent(overview: overview, state: state);
          },
        ),
      ),
    ),
  );
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({required this.overview, required this.state});
  final PreparationOverview overview;
  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final current = overview.programs.where((p) => p.isCurrent).firstOrNull;
    final otherGoals = overview.goals
        .where((g) => g.id != current?.goalId)
        .toList();
    final pending =
        overview.weeklyWorkouts
            .where(
              (w) =>
                  w.status == ScheduledWorkoutStatus.planned ||
                  w.status == ScheduledWorkoutStatus.inProgress,
            )
            .toList()
          ..sort((a, b) {
            // Retomar una ejecución tiene prioridad visual, sin cambiar su pauta.
            if (a.status != b.status) {
              return a.status == ScheduledWorkoutStatus.inProgress ? -1 : 1;
            }
            final date = a.scheduledDate.compareTo(b.scheduledDate);
            if (date != 0) return date;
            final time = (a.scheduledTime ?? '99:99').compareTo(
              b.scheduledTime ?? '99:99',
            );
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final completed = overview.weeklyWorkouts
        .where((w) => w.status == ScheduledWorkoutStatus.completed)
        .length;
    final dateFormat = DateFormat('dd/MM');

    final preparations = <Widget>[
      HomeSectionHeading(
        title: current == null ? 'Elige una preparación' : 'Preparaciones',
        action: TextButton.icon(
          onPressed: () => context.push('/plan/goal'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Añadir'),
        ),
      ),
      const SizedBox(height: 8),
      if (otherGoals.isNotEmpty) ...[
        Text(
          'Guardar una preparación conserva su objetivo y sus marcas. Su programa empieza al configurar y aceptar una propuesta.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 12),
      ],
      if (otherGoals.isEmpty)
        Text(
          current == null ? 'Todavía no has añadido ninguna preparación.' : 'Puedes conservar otras preparaciones y sus historiales sin iniciar otro programa.',
          style: TextStyle(color: context.visuals.textMuted),
        )
      else
        for (final goal in otherGoals) ...[
          _SavedPreparationCard(
            goal: goal,
            progress: overview.programs
                .where((p) => p.goalId == goal.id)
                .firstOrNull,
          ),
          const SizedBox(height: 10),
        ],
    ];

    return RefreshIndicator(
      onRefresh: context.read<DashboardCubit>().load,
      child: ListView(
        key: const PageStorageKey('training-hub-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status == DashboardStatus.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (state.status == DashboardStatus.failure) ...[
                    _LoadFailure(onRetry: context.read<DashboardCubit>().load),
                    const SizedBox(height: 16),
                  ],
                  if (current != null)
                    _CurrentProgramCard(
                      program: current,
                      goal: overview.goals
                          .where((g) => g.id == current.goalId)
                          .firstOrNull,
                    )
                  else ...[
                    const Text(
                      'No hay programa en curso',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overview.goals.isEmpty
                          ? 'Añade la preparación que quieres entrenar. Podrás revisar el programa antes de iniciarlo.'
                          : 'Elige abajo qué preparación quieres configurar o retomar. Ninguna está entrenando automáticamente ahora.',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ...preparations,
                  ],
                  const SizedBox(height: 24),
                  const HomeSectionHeading(title: 'Esta semana'),
                  const SizedBox(height: 10),
                  EntrenaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${dateFormat.format(overview.weekStart)} – ${dateFormat.format(overview.weekStart.add(const Duration(days: 6)))}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$completed completadas · ${pending.length} pendientes',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overview.weeklyWorkouts.isEmpty
                              ? 'No hay sesiones programadas esta semana. Puedes consultar la agenda y añadir entrenamientos extra.'
                              : 'Incluye las sesiones de tu programa y los entrenamientos extra que has añadido.',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => context.push('/plan/week'),
                          icon: const Icon(Icons.calendar_view_week_rounded),
                          label: const Text('Abrir mi semana'),
                        ),
                      ],
                    ),
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const HomeSectionHeading(
                      title: 'Pendientes de esta semana',
                    ),
                    const SizedBox(height: 10),
                    for (final item in pending.take(3)) ...[
                      _PendingSessionCard(item: item),
                      const SizedBox(height: 10),
                    ],
                    if (pending.length > 3)
                      TextButton(
                        onPressed: () => context.push('/plan/week'),
                        child: Text(
                          'Ver las ${pending.length} sesiones pendientes en Mi semana',
                        ),
                      ),
                  ],
                  if (current != null) ...[
                    const SizedBox(height: 24),
                    ...preparations,
                  ],
                  const SizedBox(height: 24),
                  EntrenaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Disponibilidad y material',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          current == null
                              ? 'Datos compartidos de tu cuenta. Se usarán al configurar tu próximo programa; guardarlos no inicia ningún entrenamiento.'
                              : 'Son los mismos datos que revisas en Mi programa. Se usan para repartir el tiempo y elegir ejercicios compatibles. Los cambios se aplican en la siguiente adaptación; no sustituyen las sesiones ya iniciadas.',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                        const SizedBox(height: 12),
                        if (overview.trainingContext case final settings?) ...[
                          Text(
                            settings.availability.values.any((m) => m > 0)
                                ? [
                                    for (var day = 1; day <= 7; day++)
                                      if ((settings.availability['$day'] ?? 0) >
                                          0)
                                        '${const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][day - 1]} ${settings.availability['$day']} min',
                                  ].join(' · ')
                                : 'Días y minutos pendientes de indicar.',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            settings.equipment.isEmpty
                                ? 'Sin material adicional indicado.'
                                : 'Material: ${(settings.equipment.toList()..sort()).map(performanceEquipmentLabel).join(', ')}.',
                          ),
                          if (!settings.capacityConfirmed ||
                              settings.reportsPain) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Revisa también la confirmación de capacidad y molestias antes de pautar entrenamientos.',
                            ),
                          ],
                        ] else
                          const Text(
                            'Aún no has guardado días, minutos y material para el programa.',
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/profile/preferences'),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Editar disponibilidad y material'),
                        ),
                      ],
                    ),
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

class _CurrentProgramCard extends StatelessWidget {
  const _CurrentProgramCard({required this.program, required this.goal});
  final AdaptiveProgramProgress program;
  final PreparationGoal? goal;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    tone: EntrenaCardTone.accent,
    coverImage: preparationCoverProvider(goal?.program.cover?.headerUrl),
    focalX: goal?.program.cover?.headerFocalX ?? 0.5,
    focalY: goal?.program.cover?.headerFocalY ?? 0.5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PROGRAMA EN CURSO · ${preparationStatusLabel(program)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          program.name,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          program.message,
          style: TextStyle(color: context.visuals.textMuted),
        ),
        if (goal?.targetDate case final date?) ...[
          const SizedBox(height: 8),
          Text('Fecha objetivo: ${DateFormat('dd/MM/yyyy').format(date)}'),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              context.push('/plan/goal/${program.goalId}/training'),
          icon: Icon(
            program.needsReview ? Icons.info_outline : Icons.tune_rounded,
          ),
          label: Text(
            program.needsReview ? 'Revisar lo pendiente' : 'Ver mi programa',
          ),
        ),
        TextButton(
          onPressed: () => context.push('/plan/goal/${program.goalId}'),
          child: const Text('Gestionar esta preparación'),
        ),
      ],
    ),
  );
}

class _PendingSessionCard extends StatelessWidget {
  const _PendingSessionCard({required this.item});
  final ScheduledWorkout item;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${DateFormat('dd/MM').format(item.scheduledDate)}${item.scheduledTime == null ? '' : ' · ${item.scheduledTime}'} · ${item.status == ScheduledWorkoutStatus.inProgress ? 'En curso' : 'Pendiente'}',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          item.templateName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (item.estimatedDurationMinutes case final minutes?) ...[
          const SizedBox(height: 6),
          Text(
            '$minutes min previstos',
            style: TextStyle(color: context.visuals.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(homeWorkoutRoute(item)),
          icon: Icon(
            item.status == ScheduledWorkoutStatus.inProgress
                ? Icons.play_arrow_rounded
                : Icons.arrow_forward_rounded,
          ),
          label: Text(
            item.status == ScheduledWorkoutStatus.inProgress
                ? 'Retomar sesión'
                : 'Ver sesión',
          ),
        ),
      ],
    ),
  );
}

class _SavedPreparationCard extends StatelessWidget {
  const _SavedPreparationCard({required this.goal, required this.progress});
  final PreparationGoal goal;
  final AdaptiveProgramProgress? progress;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    tone: EntrenaCardTone.progress,
    coverImage: preparationCoverProvider(goal.program.cover?.cardUrl),
    focalX: goal.program.cover?.focalX ?? 0.5,
    focalY: goal.program.cover?.focalY ?? 0.5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          preparationStatusLabel(progress),
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          goal.program.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (goal.targetDate case final date?)
          Text('Pruebas: ${DateFormat('dd/MM/yyyy').format(date)}'),
        const SizedBox(height: 8),
        Text(
          progress?.isPaused == true
              ? 'Tu progreso se conserva. Revisa la propuesta antes de retomarlo.'
              : progress?.status == 'complete'
              ? 'Programa finalizado. Puedes consultar tu preparación y sus resultados.'
              : 'Preparación guardada. Falta revisar y aceptar su programa de entrenamiento.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: goal.id == null
              ? null
              : () => context.push('/plan/goal/${goal.id}'),
          child: const Text('Gestionar preparación'),
        ),
        if (goal.id != null && progress?.status != 'complete')
          TextButton(
            onPressed: () => context.push('/plan/goal/${goal.id}/training'),
            child: Text(
              progress?.isPaused == true
                  ? 'Retomar programa'
                  : 'Configurar programa',
            ),
          ),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'No hemos podido actualizar Mi plan. Puede que los datos mostrados hayan cambiado.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar cargar Mi plan'),
        ),
      ],
    ),
  );
}
