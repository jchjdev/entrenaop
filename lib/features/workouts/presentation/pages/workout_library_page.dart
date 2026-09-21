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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Biblioteca'),
      ),
      body: BlocBuilder<WorkoutLibraryCubit, WorkoutLibraryState>(
        builder: (context, state) {
          if (state.status == WorkoutLibraryStatus.initial ||
              (state.status == WorkoutLibraryStatus.loading &&
                  state.workouts.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WorkoutLibraryStatus.failure &&
              state.workouts.isEmpty) {
            return _Failure(
              message:
                  state.errorMessage ?? 'No hemos podido abrir la biblioteca.',
              onRetry: context.read<WorkoutLibraryCubit>().load,
            );
          }
          return _LibraryContent(state: state);
        },
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({required this.state});

  final WorkoutLibraryState state;

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
                  const Text(
                    'Sesiones de EntrenaOP',
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Entrenamientos públicos para elegir y ejecutar libremente. No son todavía una prescripción adaptativa.',
                    style: TextStyle(color: Colors.white60, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  if (state.workouts.isEmpty)
                    const _EmptyLibrary()
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
                          itemCount: state.workouts.length,
                          itemBuilder: (context, index) =>
                              _WorkoutCard(workout: state.workouts[index]),
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
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFF151515),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no hay sesiones públicas disponibles.',
          textAlign: TextAlign.center,
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
