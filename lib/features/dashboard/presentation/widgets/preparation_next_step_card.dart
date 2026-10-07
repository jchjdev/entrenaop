import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Presenta el siguiente paso existente, sin decidir ni iniciar un programa.
class PreparationNextStepCard extends StatelessWidget {
  const PreparationNextStepCard({
    required this.nextStep,
    this.goalNeedingAssessment,
    this.program,
    super.key,
  });

  final PreparationNextStep nextStep;
  final PreparationGoal? goalNeedingAssessment;
  final AdaptiveProgramProgress? program;

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
            : program!.isCurrent
            ? 'Tu programa está en marcha'
            : 'Revisa el estado de tu programa',
        description: program!.message,
        action: program!.isPaused
            ? 'Retomar mi programa'
            : program!.needsReview
            ? 'Revisar lo pendiente'
            : program!.isCurrent
            ? 'Ver mis entrenamientos'
            : 'Ver mi programa',
        route: !program!.isCurrent || program!.needsReview
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
        route:
            '/plan/goal/${goalNeedingAssessment!.id}/${switch (goalNeedingAssessment!.programId) {
              PreparationProgramIds.armedForcesTroopEntry => 'troop-assessment',
              PreparationProgramIds.fasPeriodicAssessment => 'periodic-assessment',
              _ => 'program-assessment',
            }}',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 38, color: Theme.of(context).colorScheme.secondary),
          if (program != null) ...[
            const SizedBox(height: 12),
            Text(
              program!.name,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: context.visuals.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.push(route),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
