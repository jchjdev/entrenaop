import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_scope.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_cover_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Consulta del catálogo antes del alta; abrirla no crea una preparación.
class PreparationProgramPage extends StatelessWidget {
  const PreparationProgramPage({required this.programId, super.key});
  final String programId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Programa de preparación')),
    body: BlocConsumer<PreparationGoalCubit, PreparationGoalState>(
      listener: (context, state) {
        if (state.status == PreparationGoalStatus.saved) {
          final goal = state.goals
              .where((g) => g.programId == programId)
              .firstOrNull;
          if (goal?.id != null) context.push('/plan/goal/${goal!.id}');
        } else if (state.status == PreparationGoalStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? 'No se pudo guardar la preparación.',
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == PreparationGoalStatus.loading ||
            state.status == PreparationGoalStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }
        final program = state.programs
            .where((p) => p.id == programId)
            .firstOrNull;
        if (program == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Este programa no está disponible en el catálogo.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: context.read<PreparationGoalCubit>().load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final goal = state.goals
            .where((g) => g.programId == programId)
            .firstOrNull;
        final free = PlanPreviewScope.isFree(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EntrenaCard(
                    tone: EntrenaCardTone.progress,
                    coverImage: preparationCoverProvider(
                      program.cover?.headerUrl,
                    ),
                    focalX: program.cover?.headerFocalX ?? .5,
                    focalY: program.cover?.headerFocalY ?? .5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          program.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(switch (program.kind) {
                          PreparationProgramKind.access => 'Prepara las pruebas físicas de acceso de este programa.',
                          PreparationProgramKind.internalAssessment => 'Prepara la evaluación física periódica de este programa.',
                        }),
                        if (goal != null) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Ya está en tus preparaciones.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cómo empezar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Añade la preparación, indica la fecha de tus pruebas y completa las marcas y el contexto que te pida el programa.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Puedes guardar varias preparaciones. Activar otra requiere revisar el cambio; explorar el catálogo o añadirla no pausa tu programa actual.',
                  ),
                  if (PlanPreviewScope.stateOf(context)?.available ??
                      false) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Entrenamiento adaptativo con Pro',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'La generación y adaptación de entrenamientos utiliza tus resultados, disponibilidad y material.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (goal?.id != null)
                    FilledButton.icon(
                      onPressed: () => context.push('/plan/goal/${goal!.id}'),
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Gestionar preparación'),
                    )
                  else if (free)
                    FilledButton.icon(
                      onPressed: () => context.push('/plan/pro'),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Conocer Pro'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: state.status == PreparationGoalStatus.saving
                          ? null
                          : () => context.read<PreparationGoalCubit>().add(
                              program,
                            ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Añadir preparación'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
