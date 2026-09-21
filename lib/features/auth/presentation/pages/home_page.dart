import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
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
                  const SizedBox(height: 12),
                  const Text(
                    '¿Entrenamos?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Elige una preparación o empieza una sesión.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PreparationsCarousel(goals: overview.goals),
                  const SizedBox(height: 22),
                  const _TrainingHero(),
                  const SizedBox(height: 22),
                  _QuickActions(assessment: assessment),
                  const SizedBox(height: 26),
                  const Text(
                    'Completa tu contexto',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Lo que ya sabemos y el siguiente dato útil.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
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

class _PreparationsCarousel extends StatelessWidget {
  const _PreparationsCarousel({required this.goals});

  final List<PreparationGoal> goals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tus preparaciones',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openPreparationCatalog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (goals.isEmpty)
          Card(
            color: const Color(0xFF151515),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFFFF8A50),
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Añade tu primera preparación',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Elige una oposición o prueba del catálogo verificado.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _openPreparationCatalog(context),
                    child: const Text('Explorar'),
                  ),
                ],
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (index, goal) in goals.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  _PreparationCard(goal: goal),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.goal});

  final PreparationGoal goal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 286,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF171717),
        child: InkWell(
          onTap: () => _openPreparationCatalog(context),
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.military_tech_outlined,
                  color: Color(0xFFFF8A50),
                  size: 30,
                ),
                const SizedBox(height: 18),
                Text(
                  goal.program.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  goal.targetDate == null
                      ? 'Fecha todavía no indicada'
                      : 'Pruebas · ${_formatDate(goal.targetDate!)}',
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text(
                      'Gestionar preparación',
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
      ),
    );
  }
}

Future<void> _openPreparationCatalog(BuildContext context) async {
  await context.push('/plan/goal');
  if (!context.mounted) return;
  await context.read<DashboardCubit>().load();
}

class _TrainingHero extends StatelessWidget {
  const _TrainingHero();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF28160F),
      child: InkWell(
        onTap: () => context.push('/plan/starter-session'),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SESIÓN DISPONIBLE',
                  style: TextStyle(
                    color: Color(0xFFFFC3A5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sesión inicial de EntrenaOP',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Una sesión convencional completa para probar el entrenamiento real.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 19),
              FilledButton.icon(
                onPressed: () => context.push('/plan/starter-session'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Ver sesión'),
              ),
              const SizedBox(height: 9),
              const Text(
                'No es todavía una recomendación personalizada.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.assessment});

  final PhysicalAssessmentHistoryEntry? assessment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accesos rápidos',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickActionCard(
                icon: Icons.grid_view_rounded,
                label: 'Biblioteca',
                description: 'Explorar sesiones públicas',
                onTap: () => context.push('/plan/library'),
              ),
              const SizedBox(width: 10),
              _QuickActionCard(
                icon: Icons.event_note_rounded,
                label: 'Mi plan',
                description: 'Sesiones y configuración',
                onTap: () => context.go('/plan'),
              ),
              const SizedBox(width: 10),
              _QuickActionCard(
                icon: Icons.monitor_heart_outlined,
                label: assessment == null ? 'Evaluarme' : 'Mis marcas',
                description: assessment == null
                    ? 'Registrar punto de partida'
                    : 'Consultar la última valoración',
                onTap: () => assessment == null
                    ? context.push('/assessment/initial')
                    : context.go('/assessment/history/physical'),
              ),
              const SizedBox(width: 10),
              _QuickActionCard(
                icon: Icons.insights_rounded,
                label: 'Evolución',
                description: 'Historial de entrenamiento',
                onTap: () => context.go('/assessment/history'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF151515),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFFFF8A50), size: 27),
                const SizedBox(height: 18),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
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
      PreparationNextStep.preparationGoal => (
        icon: Icons.flag_outlined,
        title: 'Define qué pruebas estás preparando',
        description:
            'Añade una o varias preparaciones del catálogo oficial verificado.',
        action: 'Explorar preparaciones',
        route: '/plan/goal',
      ),
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
        route: '/plan/preferences',
      ),
      PreparationNextStep.professionalReview => (
        icon: Icons.health_and_safety_outlined,
        title: 'La planificación automática está bloqueada',
        description:
            'Has indicado una limitación que debe revisarse antes de prescribir entrenamiento.',
        action: 'Revisar respuesta',
        route: '/plan/preferences',
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
                  nextStep == PreparationNextStep.physicalAssessment ||
                      nextStep == PreparationNextStep.preparationGoal
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
          ? context.go('/assessment/history/physical')
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
      onPressed: () => context.push('/plan/preferences'),
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

String _formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
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
