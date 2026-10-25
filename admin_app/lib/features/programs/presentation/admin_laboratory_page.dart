import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/admin_shell.dart';
import '../../exercises/data/admin_exercise_repository.dart';
import 'admin_performance_progression_lab.dart';
import 'admin_push_up_policy_lab.dart';

class AdminLaboratoryPage extends StatelessWidget {
  const AdminLaboratoryPage({
    required this.repository,
    this.pushUps = false,
    super.key,
  });
  final AdminExerciseRepository repository;
  final bool pushUps;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminShellScope.hidesAppBar(context)
        ? null
        : AppBar(title: const Text('Laboratorio')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: ProfessionalWorkspaceScope.pageConstraints(
            context,
            maxWidth: 1000,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laboratorio',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              EntrenaCard(
                child: const Text(
                  'Datos simulados · Estas herramientas permiten explorar reglas deportivas. '
                  'No guardan resultados de deportistas, no publican sesiones ni modifican planes.',
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Fuerza y rendimiento'),
                    selected: !pushUps,
                    onSelected: (_) => context.go('/laboratory'),
                  ),
                  ChoiceChip(
                    label: const Text('Política de flexiones'),
                    selected: pushUps,
                    onSelected: (_) => context.go('/laboratory/push-ups'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (pushUps)
                AdminPushUpPolicyLab(repository: repository)
              else
                AdminPerformanceProgressionLab(repository: repository),
            ],
          ),
        ),
      ),
    ),
  );
}
