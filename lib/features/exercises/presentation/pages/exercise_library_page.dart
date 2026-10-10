import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/exercise_library_filter.dart';
import 'package:entrenaop/features/exercises/presentation/widgets/exercise_reference_video.dart';
import 'package:entrenaop/features/library/presentation/library_search.dart';
import 'package:entrenaop/features/library/presentation/widgets/library_search_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';

class ExerciseLibraryPage extends StatelessWidget {
  const ExerciseLibraryPage({
    this.initialPersonalTab = false,
    this.loadProAccess,
    super.key,
  });
  final bool initialPersonalTab;
  final LoadProAccess? loadProAccess;

  Future<bool> _create(BuildContext tabContext) async {
    final created = await tabContext.push<String>('/library/exercises/new');
    if (created == null || !tabContext.mounted) return false;
    DefaultTabController.of(tabContext).animateTo(1);
    await tabContext.read<ExerciseLibraryCubit>().load();
    return true;
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: initialPersonalTab ? 1 : 0,
    child: Builder(
      builder: (tabContext) => Scaffold(
        appBar: AppBar(
          title: const Text('Ejercicios'),
          leading: IconButton(
            tooltip: 'Volver a Biblioteca',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/library'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'EntrenaOP'),
              Tab(text: 'Mis ejercicios'),
            ],
          ),
        ),
        body: BlocBuilder<ExerciseLibraryCubit, ExerciseLibraryState>(
          builder: (context, state) {
            final load = context.read<ExerciseLibraryCubit>().load;
            if ((state.status == ExerciseLibraryStatus.initial ||
                    state.status == ExerciseLibraryStatus.loading) &&
                state.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == ExerciseLibraryStatus.failure &&
                state.isEmpty) {
              return _LoadFailure(onRetry: load);
            }
            return TabBarView(
              children: [
                _ExerciseCollection(
                  state: state,
                  personal: false,
                  onCreate: () => _create(tabContext),
                ),
                _ExerciseCollection(
                  state: state,
                  personal: true,
                  loadProAccess: loadProAccess,
                  onCreate: () => _create(tabContext),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ExerciseCollection extends StatefulWidget {
  const _ExerciseCollection({
    required this.state,
    required this.personal,
    required this.onCreate,
    this.loadProAccess,
  });
  final ExerciseLibraryState state;
  final bool personal;
  final Future<bool> Function() onCreate;
  final LoadProAccess? loadProAccess;
  @override
  State<_ExerciseCollection> createState() => _ExerciseCollectionState();
}

class _ExerciseCollectionState extends State<_ExerciseCollection>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  String? _muscle, _type, _equipment, _difficulty;
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _muscle = null;
    _type = null;
    _equipment = null;
    _difficulty = null;
  });
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = widget.state;
    final personal = widget.personal;
    final allExercises = personal
        ? state.personalExercises
        : state.officialExercises;
    final filter = ExerciseLibraryFilter(
      query: _search.text,
      muscle: _muscle,
      type: _type,
      equipment: _equipment,
      difficulty: _difficulty,
    );
    final exercises = allExercises.where(filter.matches).toList();
    final load = context.read<ExerciseLibraryCubit>().load;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    personal ? 'Tus ejercicios' : 'Ejercicios de EntrenaOP',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    personal
                        ? 'Tu colección privada para construir sesiones a tu manera.'
                        : 'Consulta los movimientos y sus indicaciones antes de usarlos en tus sesiones.',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                  if (personal) ...[
                    if (widget.loadProAccess != null)
                      PersonalQuotaBanner(
                        key: ValueKey(allExercises.length),
                        load: widget.loadProAccess!,
                        sessions: false,
                      ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (await widget.onCreate() && mounted) _reset();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Crear ejercicio'),
                      ),
                    ),
                  ],
                  if (state.status == ExerciseLibraryStatus.loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (state.status == ExerciseLibraryStatus.failure) ...[
                    const SizedBox(height: 16),
                    _LoadFailure(onRetry: load),
                  ],
                  const SizedBox(height: 20),
                  LibrarySearchControls(
                    controller: _search,
                    searchLabel: 'Buscar ejercicios',
                    onQueryChanged: (_) => setState(() {}),
                    onReset: _reset,
                    activeFilters: [
                      _muscle,
                      _type,
                      _equipment,
                      _difficulty,
                    ].whereType<String>().length,
                    resultCount: exercises.length,
                    totalCount: allExercises.length,
                    resultNoun: 'ejercicios',
                    filterFields: [
                      LibraryFilterField(
                        label: 'Grupo muscular',
                        value: _muscle,
                        options: libraryOptions(
                          allExercises.expand((e) => e.muscleGroups),
                        ),
                        onChanged: (value) => setState(() => _muscle = value),
                      ),
                      LibraryFilterField(
                        label: 'Tipo / medición',
                        value: _type,
                        options: libraryOptions(
                          allExercises.map((e) => e.exerciseType),
                        ),
                        onChanged: (value) => setState(() => _type = value),
                      ),
                      LibraryFilterField(
                        label: 'Material',
                        value: _equipment,
                        options: libraryOptions(
                          allExercises.expand((e) => e.equipment),
                        ),
                        onChanged: (value) =>
                            setState(() => _equipment = value),
                      ),
                      LibraryFilterField(
                        label: 'Dificultad',
                        value: _difficulty,
                        options: libraryOptions(
                          allExercises.map((e) => e.difficulty),
                        ),
                        onChanged: (value) =>
                            setState(() => _difficulty = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (allExercises.isEmpty)
                    EntrenaCard(
                      tone: EntrenaCardTone.quiet,
                      child: Text(
                        personal
                            ? 'Todavía no has creado ejercicios. Puedes empezar con “Crear ejercicio”.'
                            : 'Todavía no hay ejercicios de EntrenaOP disponibles.',
                      ),
                    )
                  else if (exercises.isEmpty)
                    EntrenaCard(
                      tone: EntrenaCardTone.quiet,
                      child: Column(
                        children: [
                          const Text(
                            'No hay ejercicios que coincidan con tu búsqueda.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _reset,
                            child: const Text('Limpiar búsqueda y filtros'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...exercises.map(
                      (exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExerciseTile(
                          exercise: exercise,
                          personal: personal,
                        ),
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

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.personal});
  final ExerciseEntity exercise;
  final bool personal;

  @override
  Widget build(BuildContext context) => EntrenaCard(
    tone: EntrenaCardTone.quiet,
    onTap: () async {
      final cubit = context.read<ExerciseLibraryCubit>();
      final action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar detalle',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  exercise.origin == ExerciseOrigin.system
                      ? 'EntrenaOP'
                      : 'Tu ejercicio personal',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
                if (exercise.thumbnailUrl case final image?) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      image,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  exercise.description?.trim().isNotEmpty == true
                      ? exercise.description!
                      : 'Este ejercicio aún no tiene una descripción.',
                ),
                if (exercise.muscleGroups.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Grupos musculares',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(exercise.muscleGroups.join(' · ')),
                ],
                if (exercise.equipment.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Material',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(exercise.equipment.join(' · ')),
                ],
                if (exercise.videoUrl case final video?
                    when video.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ExerciseReferenceVideo(url: video),
                ],
                if (personal && !exercise.isPublic) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar ejercicio'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      if (action != 'edit' || !context.mounted || cubit.isClosed) return;
      final saved = await context.push<String>(
        '/library/exercises/${exercise.id}/edit',
      );
      if (saved != null && !cubit.isClosed) await cubit.load();
    },
    child: Row(
      children: [
        Icon(Icons.fitness_center_rounded, color: context.visuals.textMuted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (exercise.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(
                  exercise.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Ver ejercicio',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_outlined),
        const SizedBox(height: 12),
        const Text(
          'No hemos podido cargar los ejercicios.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
