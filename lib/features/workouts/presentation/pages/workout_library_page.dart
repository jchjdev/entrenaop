import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WorkoutLibraryPage extends StatelessWidget {
  const WorkoutLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: context.pop,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Sesiones'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Biblioteca'),
              Tab(text: 'Mis sesiones'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final createdId = await context.push<String>('/plan/library/new');
            if (createdId != null && context.mounted) {
              await context.read<WorkoutLibraryCubit>().load();
              if (context.mounted) {
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
                    state.errorMessage ?? 'No hemos podido abrir tus sesiones.',
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
                  state: state,
                  workouts: state.personalWorkouts,
                  personal: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.state,
    required this.workouts,
    required this.personal,
  });

  final WorkoutLibraryState state;
  final List<WorkoutTemplateSummary> workouts;
  final bool personal;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: context.read<WorkoutLibraryCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                  if (workouts.isEmpty)
                    _EmptyLibrary(personal: personal)
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
                                mainAxisExtent: 222,
                              ),
                          itemCount: workouts.length,
                          itemBuilder: (context, index) =>
                              _WorkoutCard(workout: workouts[index]),
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
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final WorkoutTemplateSummary workout;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF171717),
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
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Color(0xFFFF8A50),
                    ),
                  ),
                  const Spacer(),
                  if (workout.estimatedDurationMinutes case final minutes?)
                    Text(
                      '$minutes min',
                      style: const TextStyle(color: Colors.white54),
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
                  workout.description ?? 'Sesión pública de EntrenaOP.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, height: 1.35),
                ),
              ),
              const Row(
                children: [
                  Text(
                    'Ver sesión',
                    style: TextStyle(
                      color: Color(0xFFFF8A50),
                      fontWeight: FontWeight.w700,
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.personal});

  final bool personal;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151515),
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
