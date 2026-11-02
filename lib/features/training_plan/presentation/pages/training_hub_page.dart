import '../widgets/training_equipment_labels.dart';
import '../widgets/training_guided_programs.dart';

import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/presentation/images/editorial_cover_provider.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/dashboard/presentation/home_day_selection.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_section_heading.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/preparation_status_label.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';

import '../widgets/training_preparation_overview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Una URL directa de preparación no necesita cargar el resumen de su raíz.
/// Tras visitarla se conserva el Cubit al abrir sus rutas hijas.
class TrainingHubEntry extends StatefulWidget {
  const TrainingHubEntry({
    required this.createCubit,
    this.loadProAccess,
    this.guidedPrograms,
    this.initialSection,
    this.selectedDate,
    super.key,
  });
  final DashboardCubit Function() createCubit;
  final LoadProAccess? loadProAccess;
  final GuidedProgramRepository? guidedPrograms;
  final String? initialSection;
  final DateTime? selectedDate;

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
          child: TrainingHubPage(
            loadProAccess: widget.loadProAccess,
            guidedPrograms: widget.guidedPrograms,
            initialSection: widget.initialSection,
            selectedDate: widget.selectedDate,
          ),
        )
      : const SizedBox.shrink();
}

/// Organiza consultas existentes sin prescribir ni iniciar entrenamientos.
class TrainingHubPage extends StatefulWidget {
  const TrainingHubPage({
    this.loadProAccess,
    this.guidedPrograms,
    this.initialSection,
    this.selectedDate,
    super.key,
  });
  final LoadProAccess? loadProAccess;
  final GuidedProgramRepository? guidedPrograms;
  final String? initialSection;
  final DateTime? selectedDate;

  @override
  State<TrainingHubPage> createState() => _TrainingHubPageState();
}

class _TrainingHubPageState extends State<TrainingHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _guidedRefreshVersion = 0;

  int _sectionIndex(String? section) => switch (section) {
    'programs' || 'guided' => 1,
    'availability' => 2,
    _ => 0,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: _sectionIndex(widget.initialSection),
    );
  }

  @override
  void didUpdateWidget(covariant TrainingHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection &&
        widget.initialSection != null) {
      _tabs.animateTo(_sectionIndex(widget.initialSection));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<DashboardCubit>().load();
    if (mounted) setState(() => _guidedRefreshVersion++);
  }

  void _openWeek() {
    final overview = context.read<DashboardCubit>().state.overview;
    final now = DateTime.now();
    final start = overview?.weekStart;
    final day =
        widget.selectedDate ??
        (start == null ||
                (!now.isBefore(start) &&
                    now.isBefore(start.add(const Duration(days: 7))))
            ? now
            : start);
    context.push('/plan/week?date=${homeDateParam(day)}');
  }

  @override
  Widget build(BuildContext context) => SectionRefreshBoundary(
    location: '/plan',
    onVisible: _refresh,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Entrenar'),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3)
            TextButton.icon(
              onPressed: _openWeek,
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Ver semana'),
            ),
          if (MediaQuery.sizeOf(context).width >= 840)
            IconButton(
              tooltip: 'Actualizar Entrenar',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openWeek,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Ver semana'),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  tabs: const [
                    Tab(text: 'Preparación'),
                    Tab(text: 'Programas'),
                    Tab(text: 'Disponibilidad'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) {
                  final overview = state.overview;
                  if (overview == null &&
                      state.status != DashboardStatus.failure) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (overview == null) {
                    return SingleChildScrollView(
                      child: _LoadFailure(onRetry: _refresh),
                    );
                  }
                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _TrainingPane(
                        storageKey: 'training-preparation-scroll',
                        state: state,
                        onRefresh: _refresh,
                        children: [
                          TrainingPreparationOverview(
                            overview: overview,
                            loadProAccess: widget.loadProAccess,
                          ),
                        ],
                      ),
                      _TrainingPane(
                        storageKey: 'training-programs-scroll',
                        state: state,
                        onRefresh: _refresh,
                        children: [
                          if (widget.guidedPrograms case final repository?)
                            TrainingGuidedPrograms(
                              repository: repository,
                              refreshVersion: _guidedRefreshVersion,
                            )
                          else
                            const EntrenaCard(
                              child: Text(
                                'No se han podido cargar tus programas.',
                              ),
                            ),
                        ],
                      ),
                      _TrainingPane(
                        storageKey: 'training-availability-scroll',
                        state: state,
                        onRefresh: _refresh,
                        children: [_AvailabilityCard(overview: overview)],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Gestión secundaria: conserva todos los objetivos sin repetirlos en la portada.
class TrainingPreparationsPage extends StatelessWidget {
  const TrainingPreparationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> refresh() => context.read<DashboardCubit>().load();
    return SectionRefreshBoundary(
      location: '/plan/preparations',
      onVisible: refresh,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis preparaciones')),
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            final overview = state.overview;
            if (overview == null) {
              return state.status == DashboardStatus.failure
                  ? SingleChildScrollView(child: _LoadFailure(onRetry: refresh))
                  : const Center(child: CircularProgressIndicator());
            }
            return _TrainingPane(
              storageKey: 'training-preparations-scroll',
              state: state,
              onRefresh: refresh,
              children: [
                HomeSectionHeading(
                  title: 'Tus preparaciones',
                  action: TextButton.icon(
                    onPressed: () => context.push('/plan/goal'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Añadir'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cada preparación conserva su objetivo y sus marcas. Guardarla no activa su plan adaptativo.',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
                const SizedBox(height: 16),
                if (overview.goals.isEmpty)
                  const EntrenaCard(
                    child: Text('Todavía no has añadido ninguna preparación.'),
                  ),
                for (final goal in overview.goals) ...[
                  _SavedPreparationCard(
                    goal: goal,
                    progress: overview.programs
                        .where((p) => p.goalId == goal.id)
                        .firstOrNull,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrainingPane extends StatefulWidget {
  const _TrainingPane({
    required this.storageKey,
    required this.state,
    required this.onRefresh,
    required this.children,
  });
  final String storageKey;
  final DashboardState state;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  State<_TrainingPane> createState() => _TrainingPaneState();
}

class _TrainingPaneState extends State<_TrainingPane>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        key: PageStorageKey(widget.storageKey),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.state.status == DashboardStatus.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (widget.state.status == DashboardStatus.failure) ...[
                    _LoadFailure(onRetry: widget.onRefresh),
                    const SizedBox(height: 16),
                  ],
                  ...widget.children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.overview});
  final PreparationOverview overview;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Disponibilidad y material',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          overview.programs.any((p) => p.isCurrent)
              ? 'Son los mismos datos que revisas en tu plan adaptativo. Se usan para repartir el tiempo y elegir ejercicios compatibles. Los cambios se aplican en la siguiente adaptación; no sustituyen las sesiones ya iniciadas.'
              : 'Datos compartidos de tu cuenta. Se usarán al configurar tu próximo programa; guardarlos no inicia ningún entrenamiento.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 12),
        if (overview.trainingContext case final settings?) ...[
          Text(
            settings.availability.values.any((m) => m > 0)
                ? [
                    for (var day = 1; day <= 7; day++)
                      if ((settings.availability['$day'] ?? 0) > 0)
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
          if (!settings.capacityConfirmed || settings.reportsPain) ...[
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
  );
}

class _SavedPreparationCard extends StatelessWidget {
  const _SavedPreparationCard({required this.goal, required this.progress});
  final PreparationGoal goal;
  final AdaptiveProgramProgress? progress;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    tone: EntrenaCardTone.progress,
    coverImage: editorialCoverProvider(goal.program.cover?.cardUrl),
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
          Text('Pruebas: ${DateFormat('dd-MM-yyyy').format(date)}'),
        const SizedBox(height: 8),
        Text(
          progress?.isCurrent == true
              ? 'Tu programa está en curso. Consulta el objetivo y las marcas de esta preparación.'
              : progress?.isPaused == true
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
          child: const Text('Ver preparación'),
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
          'No hemos podido actualizar Entrenar. Puede que los datos mostrados hayan cambiado.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar cargar Entrenar'),
        ),
      ],
    ),
  );
}
