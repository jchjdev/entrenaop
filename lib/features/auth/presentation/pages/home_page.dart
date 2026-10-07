import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/dashboard/presentation/home_day_selection.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_favorites.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.favoritesRepository,
    required this.userId,
  });

  final HomeFavoritesRepository favoritesRepository;
  final String userId;

  @override
  Widget build(BuildContext context) => SectionRefreshBoundary(
    location: '/home',
    onVisible: () => context.read<DashboardCubit>().load(),
    child: Scaffold(
      appBar: AppBar(
        title: const EntrenaWordmark(width: 148),
        actions: [
          IconButton(
            tooltip: 'Abrir perfil',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar resumen',
            onPressed: () => context.read<DashboardCubit>().load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state.status == DashboardStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final overview = state.overview;
          if (overview == null &&
              (state.status == DashboardStatus.initial ||
                  state.status == DashboardStatus.loading)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (overview == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => context.read<DashboardCubit>().load(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar cargar Inicio'),
              ),
            );
          }
          return _DashboardContent(
            overview: overview,
            refreshing: state.status == DashboardStatus.loading,
            favoritesRepository: favoritesRepository,
            userId: userId,
          );
        },
      ),
    ),
  );
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.overview,
    required this.refreshing,
    required this.favoritesRepository,
    required this.userId,
  });
  final PreparationOverview overview;
  final bool refreshing;
  final HomeFavoritesRepository favoritesRepository;
  final String userId;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late DateTime _selectedDay = _initialDay();

  DateTime _initialDay() {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = widget.overview.weekStart;
    return today.isBefore(start) ||
            !today.isBefore(start.add(const Duration(days: 7)))
        ? start
        : today;
  }

  @override
  void didUpdateWidget(covariant _DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(
      oldWidget.overview.weekStart,
      widget.overview.weekStart,
    )) {
      _selectedDay = _initialDay();
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final complete = overview.weeklyWorkouts
        .where((w) => w.status == ScheduledWorkoutStatus.completed)
        .length;
    final pending = overview.weeklyWorkouts
        .where(
          (w) =>
              w.status == ScheduledWorkoutStatus.planned ||
              w.status == ScheduledWorkoutStatus.inProgress,
        )
        .length;
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.refreshing)
                    const LinearProgressIndicator(minHeight: 2),
                  _CompactWeek(
                    weekStart: overview.weekStart,
                    selectedDay: _selectedDay,
                    workouts: overview.weeklyWorkouts,
                    onSelect: (day) => setState(() => _selectedDay = day),
                  ),
                  if (overview.weeklyWorkouts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '$complete completadas · $pending pendientes esta semana',
                        style: TextStyle(
                          color: context.visuals.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  _DayHero(
                    overview: overview,
                    selectedDay: _selectedDay,
                    onOpen: _open,
                  ),
                  const SizedBox(height: 24),
                  _PreparationsSection(overview: overview, onOpen: _open),
                  const SizedBox(height: 24),
                  const HomeToolsSection(),
                  const SizedBox(height: 24),
                  EntrenaCard(
                    onTap: () => _open('/library'),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Biblioteca de entrenamientos',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Explora sesiones y ejercicios',
                                style: TextStyle(
                                  color: context.visuals.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  HomeFavorites(
                    key: ValueKey(widget.userId),
                    repository: widget.favoritesRepository,
                    userId: widget.userId,
                    onOpen: _open,
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

class _CompactWeek extends StatelessWidget {
  const _CompactWeek({
    required this.weekStart,
    required this.selectedDay,
    required this.workouts,
    required this.onSelect,
  });
  final DateTime weekStart;
  final DateTime selectedDay;
  final List<ScheduledWorkout> workouts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeSectionHeading(
        title: _homeMonth(weekStart),
        action: TextButton(
          onPressed: () =>
              context.push('/plan/week?date=${homeDateParam(selectedDay)}'),
          child: const Text('Ver semana'),
        ),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final scroll =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 23;
          final days = List.generate(7, (index) {
            final day = DateUtils.dateOnly(
              weekStart.add(Duration(days: index)),
            );
            final selected = DateUtils.isSameDay(day, selectedDay);
            final items = workouts
                .where(
                  (item) =>
                      DateUtils.isSameDay(item.scheduledDate, day) &&
                      item.status != ScheduledWorkoutStatus.skipped,
                )
                .toList();
            final color = selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface;
            return Semantics(
              label: '${_homeLongDay(day)}, ${items.length} sesiones',
              selected: selected,
              button: true,
              child: Material(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : context.visuals.surfaceLow,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('home-day-${homeDateParam(day)}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelect(day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 2,
                    ),
                    child: Column(
                      children: [
                        Text(
                          ['L', 'M', 'X', 'J', 'V', 'S', 'D'][index],
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox.square(
                          dimension: 5,
                          child: items.isEmpty
                              ? null
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? color
                                        : items.every(
                                            (w) =>
                                                w.status ==
                                                ScheduledWorkoutStatus
                                                    .completed,
                                          )
                                        ? context.visuals.success
                                        : Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          });
          if (scroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (index, day) in days.indexed) ...[
                    if (index > 0) const SizedBox(width: 5),
                    SizedBox(width: 48, child: day),
                  ],
                ],
              ),
            );
          }
          return Row(
            children: [
              for (final (index, day) in days.indexed) ...[
                if (index > 0) const SizedBox(width: 5),
                Expanded(child: day),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _DayHero extends StatelessWidget {
  const _DayHero({
    required this.overview,
    required this.selectedDay,
    required this.onOpen,
  });
  final PreparationOverview overview;
  final DateTime selectedDay;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = homeWorkoutsForDay(overview, selectedDay);
    final item = items.firstOrNull;
    final program = overview.activeProgram;
    // Un dato pendiente del programa se muestra sin alterar su estado ni agenda.
    if (item?.status != ScheduledWorkoutStatus.inProgress &&
        (program?.needsReview == true ||
            (item == null &&
                (overview.goals.isEmpty || program?.isCurrent != true)))) {
      return _NextStepCard(
        program: program,
        nextStep: overview.nextStep,
        goalNeedingAssessment: overview.goalNeedingAssessment,
      );
    }
    final today = DateUtils.isSameDay(selectedDay, DateTime.now());
    final label = today ? 'Tu sesión de hoy' : _homeLongDay(selectedDay);
    final next =
        overview.weeklyWorkouts
            .where(
              (w) =>
                  w.scheduledDate.isAfter(selectedDay) &&
                  w.status == ScheduledWorkoutStatus.planned,
            )
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final completed = item?.status == ScheduledWorkoutStatus.completed;
    final inProgress = item?.status == ScheduledWorkoutStatus.inProgress;
    final abandoned = item?.status == ScheduledWorkoutStatus.abandoned;
    final skipped = item?.status == ScheduledWorkoutStatus.skipped;
    final title = item == null
        ? 'No tienes sesión programada'
        : item.templateName;
    final description = item == null
        ? next.isEmpty
              ? 'Consulta tu semana para ver las próximas sesiones.'
              : 'Próxima sesión: ${_homeLongDay(next.first.scheduledDate)}.'
        : completed
        ? 'Sesión completada. Consulta lo que has registrado.'
        : inProgress
        ? 'Tienes una sesión en curso.'
        : abandoned
        ? 'Sesión terminada sin completar.'
        : skipped
        ? 'Esta sesión se ha omitido.'
        : item.preparationGoalId != null
        ? 'Sesión de tu programa de preparación'
        : 'Sesión que has añadido a tu semana';
    final action = item == null || skipped
        ? 'Ver mi semana'
        : inProgress
        ? 'Retomar sesión'
        : completed || abandoned
        ? 'Ver resultado'
        : 'Ver sesión';
    final route = item == null
        ? '/plan/week?date=${homeDateParam(selectedDay)}'
        : homeWorkoutRoute(item);
    return EntrenaCard(
      tone: EntrenaCardTone.accent,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item == null
                ? today
                      ? 'HOY'
                      : label.toUpperCase()
                : completed
                ? 'SESIÓN COMPLETADA'
                : inProgress
                ? 'SESIÓN EN CURSO'
                : label.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: context.visuals.textMuted)),
          if (item?.estimatedDurationMinutes case final minutes?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$minutes min previstos',
                style: TextStyle(color: context.visuals.textMuted),
              ),
            ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${items.length} sesiones en esta fecha',
                style: TextStyle(color: context.visuals.textMuted),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => onOpen(route),
            icon: Icon(
              inProgress
                  ? Icons.play_arrow_rounded
                  : completed
                  ? Icons.receipt_long_outlined
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _PreparationsSection extends StatelessWidget {
  const _PreparationsSection({required this.overview, required this.onOpen});
  final PreparationOverview overview;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HomeSectionHeading(
        title: 'Tus preparaciones',
        action: TextButton.icon(
          onPressed: () => onOpen('/plan/goal'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Añadir'),
        ),
      ),
      const SizedBox(height: 10),
      if (overview.goals.isEmpty)
        EntrenaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tus preparaciones aparecerán aquí',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige una prueba del catálogo. Podrás gestionar tu preparación y conservar su historial.',
                style: TextStyle(color: context.visuals.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => onOpen('/plan/goal'),
                child: const Text('Explorar preparaciones'),
              ),
            ],
          ),
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, goal) in overview.goals.indexed) ...[
                if (index > 0) const SizedBox(width: 10),
                SizedBox(
                  width: 250,
                  child: _PreparationCard(
                    goal: goal,
                    progress: overview.programs
                        .where((p) => p.goalId == goal.id)
                        .firstOrNull,
                    onOpen: onOpen,
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.goal,
    required this.progress,
    required this.onOpen,
  });
  final PreparationGoal goal;
  final AdaptiveProgramProgress? progress;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final status = progress == null || progress!.status == 'draft'
        ? 'Por configurar'
        : progress!.isPaused
        ? 'Pausada'
        : progress!.needsReview
        ? 'Revisión pendiente'
        : progress!.status == 'complete'
        ? 'Finalizada'
        : 'En curso';
    return EntrenaCard(
      tone: EntrenaCardTone.progress,
      onTap: goal.id == null ? null : () => onOpen('/plan/goal/${goal.id}'),
      coverImage: preparationCoverProvider(goal.program.cover?.cardUrl),
      focalX: goal.program.cover?.focalX ?? 0.5,
      focalY: goal.program.cover?.focalY ?? 0.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: Theme.of(context).colorScheme.secondary,
                size: 25,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: context.visuals.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            goal.program.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            goal.targetDate == null
                ? 'Sin fecha objetivo'
                : 'Pruebas · ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}',
            style: TextStyle(color: context.visuals.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Text(
            'Gestionar preparación →',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

const _homeMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _homeWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
String _homeMonth(DateTime date) =>
    '${_homeMonths[date.month - 1]} ${date.year}';
String _homeLongDay(DateTime date) =>
    '${_homeWeekdays[date.weekday - 1]} ${date.day} de ${_homeMonths[date.month - 1]}';

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.nextStep,
    this.goalNeedingAssessment,
    this.program,
  });
  final AdaptiveProgramProgress? program;

  final PreparationNextStep nextStep;
  final PreparationGoal? goalNeedingAssessment;

  String _assessmentRoute(PreparationGoal goal) {
    final segment = switch (goal.programId) {
      PreparationProgramIds.armedForcesTroopEntry => 'troop-assessment',
      PreparationProgramIds.fasPeriodicAssessment => 'periodic-assessment',
      _ => 'program-assessment',
    };
    return '/plan/goal/${goal.id}/$segment';
  }

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :description, :action, :route) = switch (nextStep) {
      PreparationNextStep.adaptiveProgram => (
        icon: program!.needsReview
            ? Icons.info_outline
            : Icons.play_circle_outline,
        title: program!.isPaused
            ? 'Tu programa está pausado'
            : program!.needsReview
            ? 'Tu programa necesita un dato'
            : 'Tu programa está en marcha',
        description: program!.message,
        action: program!.isPaused
            ? 'Retomar mi programa'
            : program!.needsReview
            ? 'Revisar lo pendiente'
            : 'Ver mis entrenamientos',
        route: program!.isPaused || program!.needsReview
            ? '/plan/goal/${program!.goalId}/training'
            : '/plan/week',
      ),
      PreparationNextStep.preparationGoal => (
        icon: Icons.flag_outlined,
        title: 'Define qué pruebas estás preparando',
        description:
            'Añade una o varias preparaciones del catálogo oficial verificado.',
        action: 'Explorar preparaciones',
        route: '/plan/goal',
      ),
      PreparationNextStep.assessment => (
        icon: Icons.monitor_heart_outlined,
        title: 'Registra las marcas de ${goalNeedingAssessment!.program.name}',
        description: 'Estas pruebas y su baremo pertenecen a esa preparación.',
        action: 'Registrar marcas',
        route: _assessmentRoute(goalNeedingAssessment!),
      ),
      PreparationNextStep.trainingPreferences => (
        icon: Icons.tune_rounded,
        title: 'Cuéntanos con qué tiempo cuentas',
        description: 'Tu evaluación ya está guardada. Ahora falta conocer tu disponibilidad y material.',
        action: 'Completar disponibilidad',
        route: '/profile/preferences',
      ),
      PreparationNextStep.professionalReview => (
        icon: Icons.health_and_safety_outlined,
        title: 'La planificación automática está bloqueada',
        description: 'Has indicado una limitación que debe revisarse antes de prescribir entrenamiento.',
        action: 'Revisar respuesta',
        route: '/profile/preferences',
      ),
      PreparationNextStep.awaitingValidatedPlan => (
        icon: Icons.fact_check_outlined,
        title: 'Tu contexto básico está completo',
        description: 'Entra en tu preparación para completar los datos específicos y empezar tu programa.',
        action: 'Ver preparaciones',
        route: '/plan/goal',
      ),
    };

    return EntrenaCard(
      tone: EntrenaCardTone.accent,
      padding: const EdgeInsets.all(22),
      child: Wrap(
        spacing: 20,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 38, color: const Color(0xFFFF8A50)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (nextStep == PreparationNextStep.assessment ||
                  nextStep == PreparationNextStep.preparationGoal) {
                await context.push(route);
                if (context.mounted) {
                  context.read<DashboardCubit>().load();
                }
              } else {
                await context.push(route);
                if (context.mounted) context.read<DashboardCubit>().load();
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
