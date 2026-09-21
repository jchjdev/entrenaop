import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PreparationGoalPage extends StatelessWidget {
  const PreparationGoalPage({super.key});

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
        title: const Text('Explorar preparaciones'),
      ),
      body: BlocConsumer<PreparationGoalCubit, PreparationGoalState>(
        listener: (context, state) {
          if (state.status == PreparationGoalStatus.saved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Preparaciones actualizadas.')),
            );
          } else if (state.status == PreparationGoalStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Ha ocurrido un error.'),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == PreparationGoalStatus.initial ||
              state.status == PreparationGoalStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _CatalogContent(state: state);
        },
      ),
    );
  }
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({required this.state});

  final PreparationGoalState state;

  @override
  Widget build(BuildContext context) {
    final saving = state.status == PreparationGoalStatus.saving;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Elige lo que estás preparando',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Puedes seguir varias preparaciones al mismo tiempo. Solo publicaremos programas con pruebas y baremos verificados.',
                    style: TextStyle(color: Colors.white60, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  if (state.programs.isEmpty)
                    const _EmptyCatalog()
                  else
                    for (final program in state.programs) ...[
                      _ProgramCard(
                        program: program,
                        activeGoal: _goalFor(program, state.goals),
                        saving: saving,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PreparationGoal? _goalFor(
  PreparationProgram program,
  List<PreparationGoal> goals,
) {
  for (final goal in goals) {
    if (goal.programId == program.id) return goal;
  }
  return null;
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.activeGoal,
    required this.saving,
  });

  final PreparationProgram program;
  final PreparationGoal? activeGoal;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final goal = activeGoal;
    return Card(
      color: goal == null ? const Color(0xFF151515) : const Color(0xFF21130E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  program.kind == PreparationProgramKind.access
                      ? Icons.military_tech_outlined
                      : Icons.fact_check_outlined,
                  color: const Color(0xFFFF8A50),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        goal == null
                            ? _kindLabel(program.kind)
                            : goal.targetDate == null
                            ? 'Añadida · Fecha todavía no indicada'
                            : 'Añadida · ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (goal != null)
                  const Icon(Icons.check_circle_rounded, color: Colors.green),
              ],
            ),
            const SizedBox(height: 18),
            if (goal == null)
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () => context.read<PreparationGoalCubit>().add(program),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir preparación'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => _changeDate(context, goal),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      goal.targetDate == null
                          ? 'Añadir fecha'
                          : 'Cambiar fecha',
                    ),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => _confirmArchive(context, goal),
                    child: const Text('Dejar de seguir'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeDate(BuildContext context, PreparationGoal goal) async {
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
    await context.read<PreparationGoalCubit>().updateTargetDate(goal, selected);
  }

  Future<void> _confirmArchive(
    BuildContext context,
    PreparationGoal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dejar de seguir esta preparación'),
        content: const Text(
          'Se conservará el historial. Podrás volver a añadirla más adelante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dejar de seguir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<PreparationGoalCubit>().archive(goal);
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFF151515),
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Todavía no hay preparaciones verificadas disponibles.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _kindLabel(PreparationProgramKind kind) => switch (kind) {
  PreparationProgramKind.access => 'Prueba de acceso',
  PreparationProgramKind.internalAssessment => 'Evaluación interna',
};
