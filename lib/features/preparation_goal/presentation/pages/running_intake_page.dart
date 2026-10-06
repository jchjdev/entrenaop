import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_reference_selection_section.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_week_preview_section.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Vista común del recorrido de entrada; elegir una marca no crea sesiones.
class RunningIntakePage extends StatefulWidget {
  const RunningIntakePage({
    required this.loadContext,
    required this.loadSelectionState,
    required this.chooseReference,
    required this.clearReference,
    required this.loadScheduledWorkouts,
    this.calculateWeek,
    this.previewInitialWeek,
    this.previewNextWeek,
    this.publishWeek,
    this.loadPublishedWeeks,
    this.resetPlan,
    this.now,
    this.dataOnly = false,
    this.embedded = false,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final Future<RunningInitialContext?> Function({
    required String goalId,
    required String programId,
  })
  loadContext;
  final Future<RunningReferenceSelectionState> Function(String goalId)
  loadSelectionState;
  final Future<void> Function({
    required String goalId,
    required RunningReferenceCandidate candidate,
    required bool confirmContinuity,
  })
  chooseReference;
  final Future<void> Function(String goalId) clearReference;
  final Future<List<ScheduledWorkout>> Function(DateTime start, DateTime end)
  loadScheduledWorkouts;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  calculateWeek;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  previewInitialWeek;
  final Future<Map<String, dynamic>> Function(String goalId)? previewNextWeek;
  final Future<Map<String, dynamic>> Function(String goalId, DateTime monday)?
  publishWeek;
  final Future<int> Function(String goalId)? loadPublishedWeeks;
  final Future<Map<String, dynamic>> Function(String goalId)? resetPlan;
  final DateTime Function()? now;
  final bool dataOnly;
  final bool embedded;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  State<RunningIntakePage> createState() => _RunningIntakePageState();
}

class _RunningIntakePageState extends State<RunningIntakePage> {
  Future<RunningInitialContext?>? _contextFuture;
  Future<int>? _publishedWeeksFuture;
  int _planVersion = 0;
  bool _resetting = false;
  String? _loadedGoalId;

  Future<RunningInitialContext?> _contextFor(PreparationGoal goal) {
    if (_loadedGoalId != goal.id || _contextFuture == null) {
      _loadedGoalId = goal.id;
      _contextFuture = widget.loadContext(
        goalId: goal.id!,
        programId: goal.programId,
      );
    }
    return _contextFuture!;
  }

  void _refreshContext(PreparationGoal goal) {
    setState(() {
      _contextFuture = widget.loadContext(
        goalId: goal.id!,
        programId: goal.programId,
      );
    });
  }

  Future<int> _publishedWeeks(String goalId) {
    return _publishedWeeksFuture ??= widget.loadPublishedWeeks!(goalId);
  }

  Future<void> _resetPlan(String goalId) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reiniciar planificación'),
        content: const Text(
          'Se borrarán las semanas automáticas de esta preparación, incluidas '
          'sus sesiones completadas y resultados. Tus marcas oficiales, '
          'preferencias y sesiones personales seguirán guardadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    final confirmation = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Confirmar reinicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Escribe REINICIAR para borrar este plan automático.'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                autofocus: true,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: 'Confirmación'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: confirmation.text.trim() == 'REINICIAR'
                  ? () => dialogContext.pop(true)
                  : null,
              child: const Text('Reiniciar plan'),
            ),
          ],
        ),
      ),
    );
    // El diálogo mantiene el campo durante su animación de salida.
    WidgetsBinding.instance.addPostFrameCallback((_) => confirmation.dispose());
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await widget.resetPlan!(goalId);
      if (!mounted) return;
      setState(() {
        _planVersion++;
        _publishedWeeksFuture = widget.loadPublishedWeeks!(goalId);
      });
      await context.read<PreparationDetailCubit>().load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan reiniciado. Ya puedes pautar de nuevo.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().contains('Finish or abandon')
            ? 'Termina o abandona la sesión en curso antes de reiniciar.'
            : 'No se pudo reiniciar el plan. Inténtalo de nuevo.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _body()
      : Scaffold(
          appBar: AppBar(
            title: Text(
              widget.dataOnly
                  ? 'Datos de carrera'
                  : 'Plan y preferencias de carrera',
            ),
          ),
          body: _body(),
        );
  Widget _body() => BlocBuilder<PreparationDetailCubit, PreparationDetailState>(
    builder: (context, state) {
      if (state.detail == null) {
        if (state.status == PreparationDetailStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: FilledButton(
            onPressed: context.read<PreparationDetailCubit>().load,
            child: const Text('Reintentar'),
          ),
        );
      }
      final detail = state.detail!;
      final goal = detail.goal;
      return RefreshIndicator(
        onRefresh: context.read<PreparationDetailCubit>().load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              goal.program.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              goal.programId == PreparationProgramIds.fasPeriodicAssessment
                  ? 'Aquí eliges la marca y revisas tu capacidad actual. Después puedes publicar la semana en tu agenda.'
                  : 'Aquí reunimos las marcas y el contexto que necesita el plan.',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tu referencia de 2 km',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Elige abajo una marca registrada o añade un control que ya hayas realizado. No necesitas completar una evaluación oficial para entrenar.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Registrar un control de 2 km'),
                      onPressed: () async {
                        await context.push(
                          '/plan/goal/${goal.id}/running-test/new',
                        );
                        if (context.mounted) {
                          await context.read<PreparationDetailCubit>().load();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<RunningInitialContext?>(
              future: _contextFor(goal),
              builder: (context, snapshot) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contexto de entrenamiento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator()
                      else if (snapshot.hasError)
                        const Text('No se pudo cargar el contexto guardado.')
                      else if (snapshot.data case final saved?) ...[
                        if (!widget.dataOnly)
                          Text(
                            '${saved.availableMinutesByWeekday.length} días disponibles · '
                            '${saved.reservedStrengthWeekdays.length} reservados para fuerza',
                          ),
                        Text(
                          'Carrera en las últimas 4 semanas: '
                          '${saved.recentRunningWeeks.fold<int>(0, (total, week) => total + week.runningMinutes)} min',
                        ),
                        if (saved.qualityWeeksLastFour > 0)
                          Text(
                            'Series o cambios de ritmo declarados en ${saved.qualityWeeksLastFour} de las últimas 4 semanas. Se contrastarán con las primeras sesiones registradas.',
                          ),
                        Text(
                          saved.health?.reportsPain == true ||
                                  saved.health?.requiresProfessionalReview ==
                                      true
                              ? 'Has indicado molestias o una limitación: requiere revisión antes de pautar.'
                              : 'Sin molestias ni limitaciones declaradas.',
                        ),
                      ] else
                        const Text(
                          'Indica tus días, carga reciente y estado actual.',
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Una marca oficial por sí sola no determina '
                        'la carga de la primera semana.',
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () async {
                          await context.push(
                            '/plan/goal/${goal.id}/running-context${widget.dataOnly ? '?program=true' : ''}',
                          );
                          if (context.mounted) _refreshContext(goal);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          snapshot.data == null
                              ? 'Completar contexto'
                              : 'Actualizar contexto',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<RunningInitialContext?>(
              future: _contextFor(goal),
              builder: (context, snapshot) => RunningReferenceSelectionSection(
                goalId: goal.id!,
                candidates: detail.runningReferenceCandidates,
                context: snapshot.data,
                loadState: widget.loadSelectionState,
                choose: widget.chooseReference,
                clear: widget.clearReference,
                now: widget.now ?? DateTime.now,
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.dataOnly)
              RunningWeekPreviewSection(
                key: ValueKey('running-plan-$_planVersion'),
                goalId: goal.id!,
                programId: goal.programId,
                loadContext: widget.loadContext,
                loadSelectionState: widget.loadSelectionState,
                loadScheduledWorkouts: widget.loadScheduledWorkouts,
                calculateWeek: widget.calculateWeek,
                previewInitialWeek: widget.previewInitialWeek,
                previewNextWeek: widget.previewNextWeek,
                publishWeek: widget.publishWeek,
                onPublished: widget.loadPublishedWeeks == null
                    ? null
                    : () => setState(() {
                        _publishedWeeksFuture = widget.loadPublishedWeeks!(
                          goal.id!,
                        );
                      }),
                now: widget.now ?? DateTime.now,
              ),
            if (!widget.dataOnly &&
                widget.loadPublishedWeeks != null &&
                widget.resetPlan != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _publishedWeeks(goal.id!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == 0) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _resetting ? null : () => _resetPlan(goal.id!),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reiniciar planificación'),
                    ),
                  );
                },
              ),
            ],
            if (widget.onBack != null && !widget.dataOnly)
              TextButton(onPressed: widget.onBack, child: const Text('Atrás')),
            if (widget.dataOnly) ...[
              const SizedBox(height: 16),
              const Text(
                'Al continuar revisarás el resto de tu programa. La app coordinará la semana con tu disponibilidad y tus resultados.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onContinue ?? () => context.pop(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar con el programa'),
              ),
              if (widget.onBack != null)
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Atrás'),
                ),
            ],
          ],
        ),
      );
    },
  );
}
