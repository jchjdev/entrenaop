import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/session_creation.dart';
import 'package:entrenaop/features/workouts/presentation/workout_library_filter.dart';
import 'package:entrenaop/features/library/presentation/widgets/library_search_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';

class WorkoutLibraryPage extends StatefulWidget {
  const WorkoutLibraryPage({
    super.key,
    this.initialPersonalTab = false,
    this.loadProAccess,
  });

  final bool initialPersonalTab;
  final LoadProAccess? loadProAccess;

  @override
  State<WorkoutLibraryPage> createState() => _WorkoutLibraryPageState();
}

class _WorkoutLibraryPageState extends State<WorkoutLibraryPage> {
  final _personalContentKey = GlobalKey<_LibraryContentState>();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialPersonalTab ? 1 : 0,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Volver',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/library'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Sesiones'),
            actions: [
              IconButton(
                tooltip: 'Crear ejercicio personal',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () => context.push('/exercises/new'),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'EntrenaOP'),
                Tab(text: 'Mis sesiones'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final route = await chooseSessionEditor(context);
              if (route == null || !context.mounted) return;
              final createdId = await context.push<String>(route);
              if (createdId != null && context.mounted) {
                await context.read<WorkoutLibraryCubit>().load();
                if (context.mounted) {
                  _personalContentKey.currentState?._reset();
                  DefaultTabController.of(context).animateTo(1);
                }
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear sesión'),
          ),
          body: BlocBuilder<WorkoutLibraryCubit, WorkoutLibraryState>(
            builder: (context, state) {
              if (state.status == WorkoutLibraryStatus.initial ||
                  (state.status == WorkoutLibraryStatus.loading &&
                      state.workouts.isEmpty &&
                      state.personalWorkouts.isEmpty)) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == WorkoutLibraryStatus.failure &&
                  state.workouts.isEmpty &&
                  state.personalWorkouts.isEmpty) {
                return _Failure(
                  message:
                      state.errorMessage ??
                      'No hemos podido abrir tus sesiones.',
                  onRetry: context.read<WorkoutLibraryCubit>().load,
                );
              }
              return TabBarView(
                children: [
                  _LibraryContent(
                    state: state,
                    workouts: state.workouts,
                    personal: false,
                  ),
                  _LibraryContent(
                    key: _personalContentKey,
                    state: state,
                    workouts: state.personalWorkouts,
                    personal: true,
                    loadProAccess: widget.loadProAccess,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LibraryContent extends StatefulWidget {
  const _LibraryContent({
    super.key,
    required this.state,
    required this.workouts,
    required this.personal,
    this.loadProAccess,
  });

  final WorkoutLibraryState state;
  final List<WorkoutTemplateSummary> workouts;
  final bool personal;
  final LoadProAccess? loadProAccess;

  @override
  State<_LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<_LibraryContent>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  LibrarySessionType? _type;
  LibrarySessionDuration? _duration;
  WorkoutLibraryState get state => widget.state;
  bool get personal => widget.personal;
  int get _activeFilters =>
      (_type == null ? 0 : 1) + (_duration == null ? 0 : 1);
  bool get _hasSearch => _search.text.trim().isNotEmpty || _activeFilters > 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _type = null;
    _duration = null;
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filter = WorkoutLibraryFilter(
      query: _search.text,
      type: _type,
      duration: _duration,
    );
    final workouts = widget.workouts.where(filter.matches).toList();
    return RefreshIndicator(
      onRefresh: context.read<WorkoutLibraryCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status == WorkoutLibraryStatus.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 10),
                  Text(
                    personal ? 'Tus sesiones' : 'Sesiones de EntrenaOP',
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    personal
                        ? 'Entrenamientos privados creados por ti, listos para repetir cuando quieras.'
                        : 'Entrenamientos públicos para elegir y ejecutar libremente. No son todavía una prescripción adaptativa.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  if (personal && widget.loadProAccess != null)
                    PersonalQuotaBanner(
                      key: ValueKey(state.personalWorkouts.length),
                      load: widget.loadProAccess!,
                      sessions: true,
                    ),
                  LibrarySearchControls(
                    controller: _search,
                    searchLabel: 'Buscar sesiones',
                    onQueryChanged: (_) => setState(() {}),
                    onReset: _reset,
                    activeFilters: _activeFilters,
                    resultCount: workouts.length,
                    totalCount: widget.workouts.length,
                    resultNoun: 'sesiones',
                    filterFields: [
                      LibraryFilterField(
                        label: 'Tipo de sesión',
                        value: _type?.name,
                        options: const {
                          'strength': 'Fuerza y acondicionamiento',
                          'running': 'Carrera',
                        },
                        onChanged: (value) => setState(
                          () => _type = value == null
                              ? null
                              : LibrarySessionType.values.byName(value),
                        ),
                      ),
                      LibraryFilterField(
                        label: 'Duración',
                        value: _duration?.name,
                        options: const {
                          'short': 'Menos de 30 min',
                          'medium': 'De 30 a 45 min',
                          'long': 'Más de 45 min',
                        },
                        onChanged: (value) => setState(
                          () => _duration = value == null
                              ? null
                              : LibrarySessionDuration.values.byName(value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!personal && !_hasSearch) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_outline_rounded),
                        title: const Text('Sesión inicial de EntrenaOP'),
                        subtitle: const Text(
                          'Demostración · no es tu sesión asignada.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/plan/starter-session'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.workouts.isEmpty)
                    _EmptyLibrary(personal: personal)
                  else if (workouts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'No hay sesiones que coincidan con tu búsqueda.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _reset,
                              child: const Text('Limpiar búsqueda y filtros'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent:
                                    222 *
                                    MediaQuery.textScalerOf(context).scale(14) /
                                    14,
                              ),
                          itemCount: workouts.length,
                          itemBuilder: (context, index) {
                            final workout = workouts[index];
                            return _WorkoutCard(
                              workout: workout,
                              personal: personal,
                              busy: state.busyTemplateId == workout.id,
                              onDuplicate: personal
                                  ? () => _duplicate(context, workout)
                                  : null,
                              onEdit: personal
                                  ? () => _edit(context, workout)
                                  : null,
                              onArchive: personal
                                  ? () => _archive(context, workout)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WorkoutTemplateSummary workout,
  ) async {
    final success = await context.read<WorkoutLibraryCubit>().duplicate(
      workout.id,
    );
    if (!context.mounted) return;
    final denied = context.read<WorkoutLibraryCubit>().state.accessDenied;
    if (!success && denied != null) {
      await showProRestriction(context, denied);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Hemos creado una copia de “${workout.name}”.'
              : 'No hemos podido duplicar la sesión.',
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WorkoutTemplateSummary workout,
  ) async {
    final revisedId = await context.push<String>(
      workout.isRunning
          ? '/plan/library/${workout.id}/edit-running'
          : '/plan/library/${workout.id}/edit',
    );
    if (revisedId == null || !context.mounted) return;
    await context.read<WorkoutLibraryCubit>().load();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nueva versión guardada. El historial se conserva.'),
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WorkoutTemplateSummary workout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archivar sesión'),
        content: Text(
          '“${workout.name}” dejará de aparecer en tus sesiones, pero su historial se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final success = await context.read<WorkoutLibraryCubit>().archive(
      workout.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sesión archivada. Su historial sigue intacto.'
              : 'No hemos podido archivar la sesión.',
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.personal,
    required this.busy,
    this.onDuplicate,
    this.onEdit,
    this.onArchive,
  });

  final WorkoutTemplateSummary workout;
  final bool personal;
  final bool busy;
  final Future<void> Function()? onDuplicate;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/plan/library/${workout.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x33FF8A50),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      workout.isRunning
                          ? Icons.directions_run_rounded
                          : Icons.fitness_center_rounded,
                      color: Color(0xFFFF8A50),
                    ),
                  ),
                  const Spacer(),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (workout.estimatedDurationMinutes case final minutes?)
                    Text(
                      '$minutes min',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  if (personal)
                    PopupMenuButton<_PersonalWorkoutAction>(
                      enabled: !busy,
                      tooltip: 'Opciones de sesión',
                      onSelected: (action) => switch (action) {
                        _PersonalWorkoutAction.edit => onEdit?.call(),
                        _PersonalWorkoutAction.duplicate => onDuplicate?.call(),
                        _PersonalWorkoutAction.archive => onArchive?.call(),
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _PersonalWorkoutAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _PersonalWorkoutAction.duplicate,
                          child: ListTile(
                            leading: Icon(Icons.copy_rounded),
                            title: Text('Duplicar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _PersonalWorkoutAction.archive,
                          child: ListTile(
                            leading: Icon(Icons.archive_outlined),
                            title: Text('Archivar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                workout.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  workout.description ??
                      (personal
                          ? 'Sesión privada creada por ti.'
                          : 'Sesión pública de EntrenaOP.'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, height: 1.35),
                ),
              ),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ver sesión',
                      style: TextStyle(
                        color: Color(0xFFFF8A50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Color(0xFFFF8A50),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PersonalWorkoutAction { edit, duplicate, archive }

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.personal});

  final bool personal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              personal
                  ? Icons.edit_calendar_rounded
                  : Icons.inventory_2_outlined,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              personal
                  ? 'Todavía no has creado ninguna sesión.'
                  : 'Todavía no hay sesiones públicas disponibles.',
              textAlign: TextAlign.center,
            ),
            if (personal) ...[
              const SizedBox(height: 6),
              const Text(
                'Pulsa “Crear sesión” para diseñar la primera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
