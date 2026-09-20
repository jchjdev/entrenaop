import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.fitness_center_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 10),
            Text('EntrenaOP'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar resumen',
            onPressed: () => context.read<DashboardCubit>().load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state.status == DashboardStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
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
            return _LoadFailure(
              onRetry: () => context.read<DashboardCubit>().load(),
            );
          }
          return _DashboardContent(
            overview: overview,
            refreshing: state.status == DashboardStatus.loading,
          );
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.overview, required this.refreshing});

  final PreparationOverview overview;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final assessment = overview.latestAssessment;
    final preferences = overview.preferences;

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (refreshing) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 20),
                  const Text(
                    'Tu preparación, con datos reales',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Aquí verás lo que ya conocemos, lo que falta y por qué es el siguiente paso.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _NextStepCard(nextStep: overview.nextStep),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final assessmentCard = _AssessmentCard(
                        assessment: assessment,
                      );
                      final preferencesCard = _PreferencesCard(
                        preferences: preferences,
                      );
                      if (constraints.maxWidth < 700) {
                        return Column(
                          children: [
                            assessmentCard,
                            const SizedBox(height: 12),
                            preferencesCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: assessmentCard),
                          const SizedBox(width: 12),
                          Expanded(child: preferencesCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _PlanningBoundaryCard(preferences: preferences),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.nextStep});

  final PreparationNextStep nextStep;

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :description, :action, :route) = switch (nextStep) {
      PreparationNextStep.physicalAssessment => (
        icon: Icons.monitor_heart_outlined,
        title: 'Haz tu evaluación inicial',
        description:
            'Necesitamos tus marcas reales antes de decidir qué prueba requiere atención.',
        action: 'Empezar evaluación',
        route: '/assessment/initial',
      ),
      PreparationNextStep.trainingPreferences => (
        icon: Icons.tune_rounded,
        title: 'Cuéntanos con qué tiempo cuentas',
        description:
            'Tu evaluación ya está guardada. Ahora falta conocer tu disponibilidad y material.',
        action: 'Completar disponibilidad',
        route: '/plan',
      ),
      PreparationNextStep.professionalReview => (
        icon: Icons.health_and_safety_outlined,
        title: 'La planificación automática está bloqueada',
        description:
            'Has indicado una limitación que debe revisarse antes de prescribir entrenamiento.',
        action: 'Revisar respuesta',
        route: '/plan',
      ),
      PreparationNextStep.awaitingValidatedPlan => (
        icon: Icons.fact_check_outlined,
        title: 'Tu contexto básico está completo',
        description:
            'La evaluación y tu disponibilidad están guardadas. El siguiente paso del producto es validar las reglas deportivas.',
        action: 'Ver mi evolución',
        route: '/assessment/history',
      ),
    };

    return Card(
      color: const Color(0xFF21130E),
      child: Padding(
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
              onPressed: () =>
                  nextStep == PreparationNextStep.physicalAssessment
                  ? context.push(route)
                  : context.go(route),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment});

  final PhysicalAssessmentHistoryEntry? assessment;

  @override
  Widget build(BuildContext context) {
    final entry = assessment;
    final completed = entry != null;
    final focusName = entry == null ? null : _focusTestName(entry);
    return _StatusCard(
      complete: completed,
      icon: Icons.monitor_heart_outlined,
      title: 'Evaluación física',
      description: entry == null
          ? 'Aún no tenemos marcas guardadas.'
          : '${entry.report.passedTests}/${entry.report.results.length} mínimos alcanzados\n'
                'Última: ${formatAssessmentDate(entry.completedAt)}'
                '${focusName == null ? '' : '\nFoco matemático: $focusName'}',
      actionLabel: completed ? 'Ver evolución' : 'Comenzar',
      onPressed: () => completed
          ? context.go('/assessment/history')
          : context.push('/assessment/initial'),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.preferences});

  final TrainingPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    final data = preferences;
    return _StatusCard(
      complete: data != null,
      icon: Icons.calendar_month_outlined,
      title: 'Disponibilidad',
      description: data == null
          ? 'Faltan tus días, duración y medios habituales.'
          : '${data.availableDaysPerWeek} días por semana · '
                '${data.sessionDurationMinutes} min por sesión\n'
                '${data.equipment.map((item) => item.label).join(', ')}',
      actionLabel: data == null ? 'Completar' : 'Editar',
      onPressed: () => context.go('/plan'),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.complete,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final bool complete;
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final statusColor = complete
        ? const Color(0xFF66BB6A)
        : const Color(0xFFFFB74D);
    return Card(
      color: const Color(0xFF151515),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFF8A50)),
                const Spacer(),
                Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.pending_outlined,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              style: const TextStyle(color: Colors.white60, height: 1.45),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onPressed, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningBoundaryCard extends StatelessWidget {
  const _PlanningBoundaryCard({required this.preferences});

  final TrainingPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    final needsReview = preferences?.requiresProfessionalReview == true;
    return Card(
      color: const Color(0xFF121212),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Icon(
          needsReview ? Icons.lock_outline_rounded : Icons.science_outlined,
          color: needsReview ? const Color(0xFFFFB74D) : Colors.white54,
        ),
        title: Text(
          needsReview
              ? 'Revisión necesaria antes de planificar'
              : 'Algoritmo deportivo todavía no activado',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          needsReview
              ? 'La aplicación no generará una prescripción automática mientras esta señal esté activa.'
              : 'No mostraremos rutinas automáticas hasta validar y probar las reglas de cargas y progresión.',
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

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
            const Text('No hemos podido cargar tu resumen.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String? _focusTestName(PhysicalAssessmentHistoryEntry entry) {
  final focusId = entry.recommendation?.focusTestId;
  if (focusId == null) return null;
  for (final result in entry.report.results) {
    if (result.mark.testId == focusId) return result.standard.test.name;
  }
  return null;
}

extension on TrainingEquipment {
  String get label => switch (this) {
    TrainingEquipment.none => 'Sin material',
    TrainingEquipment.pullUpBar => 'Barra de dominadas',
    TrainingEquipment.freeWeights => 'Pesas',
    TrainingEquipment.gym => 'Gimnasio',
    TrainingEquipment.runningTrack => 'Pista o zona medida',
  };
}
