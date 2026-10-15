import '../widgets/workout_session_records.dart';
import '../widgets/workout_set_entry.dart';
import '../widgets/workout_execution_labels.dart';
import '../widgets/workout_exercise_technique.dart';

import 'package:entrenaop/features/workouts/presentation/widgets/workout_execution_layout.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

import 'dart:async';

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/running_execution_assessment.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_settings_button.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_cue_permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_closure.dart';

class ActiveWorkoutPage extends StatelessWidget {
  const ActiveWorkoutPage({
    required this.timerStore,
    required this.cueService,
    super.key,
  });

  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () {
      final state = context.read<ActiveWorkoutCubit>().state;
      return state.execution != null &&
          !const [
            ActiveWorkoutStatus.completed,
            ActiveWorkoutStatus.abandoned,
            ActiveWorkoutStatus.discarded,
          ].contains(state.status);
    },
    isBusy: () =>
        context.read<ActiveWorkoutCubit>().state.draftBusy ||
        context.read<ActiveWorkoutCubit>().state.status ==
            ActiveWorkoutStatus.saving,
    confirmExit: _confirmExit,
    child: _buildContent(context),
  );

  Future<bool> _confirmExit(BuildContext context) async {
    final action = await showDialog<_SessionExitAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('¿Salir de la sesión?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Puedes retomar después, cerrar conservando lo realizado o '
              'descartar esta sesión y sus series. Los datos que no hayas '
              'confirmado quedan como borrador en este dispositivo para retomar.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _SessionExitAction.resumeLater),
              child: const Text(
                'Salir y retomar después',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _SessionExitAction.abandon),
              icon: const Icon(Icons.flag_outlined),
              label: const Text(
                'Abandonar y conservar lo realizado',
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _SessionExitAction.discard),
              child: const Text('Salir sin guardar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Seguir aquí'),
          ),
        ],
      ),
    );
    if (!context.mounted) return false;
    return switch (action) {
      _SessionExitAction.resumeLater => true,
      _SessionExitAction.abandon => _requestWorkoutAbandonment(context),
      _SessionExitAction.discard => _requestWorkoutDiscard(context),
      null => false,
    };
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleTextStyle: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Salir de la sesión',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
          buildWhen: (previous, current) => previous.status != current.status,
          builder: (context, state) => Text(switch (state.status) {
            ActiveWorkoutStatus.completed => 'Sesión completada',
            ActiveWorkoutStatus.abandoned => 'Sesión cerrada',
            ActiveWorkoutStatus.discarded => 'Sesión descartada',
            _
                when state.execution?.sets.any(
                      (set) => set.blockFormat == WorkoutBlockFormat.running,
                    ) ??
                    false =>
              'Registrar carrera',
            _ => 'Entrenamiento en curso',
          }),
        ),
        actions: [
          WorkoutCueSettingsButton(cueService: cueService),
          PopupMenuButton<String>(
            tooltip: 'Opciones de sesión',
            onSelected: (action) async {
              if (action == 'abandon') {
                await _requestWorkoutAbandonment(context);
              }
              if (action == 'discard' && context.mounted) {
                if (await _requestWorkoutDiscard(context) && context.mounted) {
                  _leaveDiscardedWorkout(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'abandon',
                child: Text('Abandonar la sesión definitivamente'),
              ),
              PopupMenuItem(value: 'discard', child: Text('Salir sin guardar')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
        builder: (context, state) {
          if (state.status == ActiveWorkoutStatus.initial ||
              state.status == ActiveWorkoutStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final execution = state.execution;
          if (state.status == ActiveWorkoutStatus.discarded) {
            return WorkoutClosureLayout(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sesión descartada. Si estaba en tu agenda, vuelve a estar pendiente.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => _leaveDiscardedWorkout(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }
          if (execution == null) {
            return _Failure(
              message: state.errorMessage ?? 'No hemos podido abrir la sesión.',
              onRetry: context.read<ActiveWorkoutCubit>().load,
            );
          }
          if (state.status == ActiveWorkoutStatus.completed ||
              execution.status == WorkoutExecutionStatus.completed) {
            return _Completed(
              execution: execution,
              pendingSyncCount: state.pendingSyncCount,
            );
          }
          if (state.status == ActiveWorkoutStatus.abandoned ||
              execution.status == WorkoutExecutionStatus.abandoned) {
            return _Abandoned(
              execution: execution,
              pendingSyncCount: state.pendingSyncCount,
            );
          }
          return WorkoutCuePermissionPrompt(
            cueService: cueService,
            child: _ActiveContent(
              state: state,
              timerStore: timerStore,
              cueService: cueService,
            ),
          );
        },
      ),
    );
  }
}

class _ActiveContent extends StatefulWidget {
  const _ActiveContent({
    required this.state,
    required this.timerStore,
    required this.cueService,
  });

  final ActiveWorkoutState state;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;

  @override
  State<_ActiveContent> createState() => _ActiveContentState();
}

class _ActiveContentState extends State<_ActiveContent> {
  int? _finalRpe;
  final _notesController = TextEditingController();
  final _averageHeartRateController = TextEditingController();
  final _maxHeartRateController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    _averageHeartRateController.dispose();
    _maxHeartRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final execution = state.execution!;
    final current = execution.currentSet;
    final saving =
        state.status == ActiveWorkoutStatus.saving || state.draftBusy;
    final cubit = context.read<ActiveWorkoutCubit>();
    final records = TextButton.icon(
      onPressed: saving ? null : () => _openRecords(context),
      icon: const Icon(Icons.format_list_numbered_rounded),
      label: Text(
        state.unconfirmedDraftCount == 0
            ? 'Series y registros'
            : 'Series y registros · ${state.unconfirmedDraftCount} por confirmar',
        textAlign: TextAlign.center,
      ),
    );
    Widget body;
    if (state.status == ActiveWorkoutStatus.resting && current != null) {
      body = WorkoutExecutionFrame(
        actions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.unconfirmedDraftCount > 0)
              FilledButton.icon(
                onPressed: saving ? null : () => _openRecords(context),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Completar datos de la serie'),
              ),
            records,
          ],
        ),
        child: WorkoutRestPanel(
          seconds: state.restSecondsRemaining,
          canSkip: state.restCanBeSkipped,
          onSkip: cubit.skipRest,
          nextName: current.exerciseName,
          nextTarget:
              '${workoutPositionLabel(current)} · ${workoutTargetLabel(current)}${current.targetRir == null ? '' : ' · RIR ${workoutNumber(current.targetRir!)}'}',
          nextImageUrl: state.exercises[current.exerciseId]?.thumbnailUrl,
          onNextTechnique: () => showWorkoutTechnique(context, current),
        ),
      );
    } else if (current?.blockFormat == WorkoutBlockFormat.amrap) {
      body = WorkoutExecutionFrame(
        actions: records,
        child: _AmrapCard(
          key: ValueKey('amrap-${current!.blockOrder}'),
          executionId: execution.id,
          sets: execution.sets
              .where((set) => set.blockOrder == current.blockOrder)
              .toList(),
          timerStore: widget.timerStore,
          cueService: widget.cueService,
          saving: saving,
          onComplete: cubit.completeCurrentAmrap,
        ),
      );
    } else if (current != null) {
      final card = WorkoutSetEntry(
        key: ValueKey(current.id),
        set: current,
        executionId: execution.id,
        timerStore: widget.timerStore,
        cueService: widget.cueService,
        saving: saving,
        onComplete: cubit.completeCurrentSet,
        onSkip: cubit.skipCurrentSet,
        onSkipWarmUp: cubit.skipWarmUp,
        records: records,
      );
      body = current.performancePrescription != null
          ? WorkoutExecutionFrame(actions: records, child: card)
          : card;
    } else {
      body = WorkoutExecutionFrame(
        actions: records,
        child: state.unconfirmedDraftCount > 0
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      'Trabajo terminado',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Revisa los datos pendientes antes de confirmar la sesión.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los borradores se conservan en este dispositivo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _openRecords(context),
                      child: const Text('Revisar series'),
                    ),
                  ],
                ),
              )
            : _FinishCard(
                rpe: _finalRpe,
                notesController: _notesController,
                averageHeartRateController: _averageHeartRateController,
                maxHeartRateController: _maxHeartRateController,
                showHeartRate:
                    execution.sets.isNotEmpty &&
                    execution.sets.every(
                      (s) => s.blockFormat == WorkoutBlockFormat.running,
                    ),
                saving: saving,
                onChanged: (v) => setState(() => _finalRpe = v),
                onFinish: _finish,
              ),
      );
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      execution.templateName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: execution.sets.isEmpty
                          ? 0
                          : execution.resolvedSetCount / execution.sets.length,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      state.drafts.values.any((d) => d.endedAt != null)
                          ? '${execution.resolvedSetCount} de ${execution.sets.length} series terminadas · ${state.unconfirmedDraftCount} por confirmar'
                          : workoutProgressLabel(execution),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    if (state.pendingSyncCount > 0)
                      Text(
                        '${state.pendingSyncCount} cambios pendientes de sincronizar',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRecords(BuildContext context) async {
    final cubit = context.read<ActiveWorkoutCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
          builder: (context, state) {
            final execution = state.execution!;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Series y registros',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar registros',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (state.status == ActiveWorkoutStatus.resting)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Text(
                          'Descanso · ${workoutClock(state.restSecondsRemaining)}',
                          style: const TextStyle(color: Color(0xFFFFA06F)),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        'Los datos pendientes y los retoques se conservan en este dispositivo hasta confirmarlos.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    Expanded(
                      child: WorkoutSessionRecords(
                        execution: execution,
                        drafts: state.drafts,
                        enabled: !state.draftBusy,
                        onEdit: (set) => _openResultEditor(context, set),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openResultEditor(
    BuildContext context,
    WorkoutExecutionSet set,
  ) async {
    final cubit = context.read<ActiveWorkoutCubit>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
          builder: (context, state) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              child: SizedBox(
                height:
                    (MediaQuery.sizeOf(context).height * .86 -
                            MediaQuery.viewInsetsOf(context).bottom)
                        .clamp(120.0, MediaQuery.sizeOf(context).height),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.status == ActiveWorkoutStatus.resting
                                  ? 'Descanso · ${workoutClock(state.restSecondsRemaining)}'
                                  : 'Revisar resultado',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar resultado',
                            onPressed: state.draftBusy
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    Expanded(
                      child: WorkoutSetEntry(
                        key: ValueKey('review-${set.id}'),
                        set: set,
                        executionId: state.execution!.id,
                        timerStore: widget.timerStore,
                        cueService: widget.cueService,
                        saving: state.draftBusy,
                        onComplete: cubit.completeCurrentSet,
                        onSkip: cubit.skipCurrentSet,
                        onSkipWarmUp: cubit.skipWarmUp,
                        review: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _finish() {
    final finalRpe = _finalRpe;
    if (finalRpe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el RPE de la sesión.')),
      );
      return;
    }
    final averageHeartRate = int.tryParse(
      _averageHeartRateController.text.trim(),
    );
    final maxHeartRate = int.tryParse(_maxHeartRateController.text.trim());
    if ((averageHeartRate != null &&
            (averageHeartRate < 30 || averageHeartRate > 250)) ||
        (maxHeartRate != null && (maxHeartRate < 30 || maxHeartRate > 250)) ||
        (averageHeartRate != null &&
            maxHeartRate != null &&
            maxHeartRate < averageHeartRate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa la frecuencia cardíaca introducida.'),
        ),
      );
      return;
    }
    context.read<ActiveWorkoutCubit>().finish(
      finalRpe: finalRpe,
      notes: _notesController.text,
      averageHeartRateBpm: averageHeartRate,
      maxHeartRateBpm: maxHeartRate,
    );
  }
}

enum _SessionExitAction { resumeLater, abandon, discard }

void _leaveDiscardedWorkout(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/plan/week');
  }
}

Future<bool> _requestWorkoutDiscard(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('¿Descartar esta sesión?'),
      content: const Text(
        'Se eliminarán también las series que ya hayas registrado en esta sesión. '
        'No quedará en el historial. Si estaba en tu agenda, volverá a estar '
        'pendiente para empezar de nuevo.\n\n'
        'Esta acción no se puede deshacer y necesita conexión.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Seguir aquí'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Descartar y salir'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  return context.read<ActiveWorkoutCubit>().discard();
}

Future<bool> _requestWorkoutAbandonment(BuildContext context) async {
  final reason = await showDialog<WorkoutAbandonmentReason>(
    context: context,
    builder: (dialogContext) {
      WorkoutAbandonmentReason? selected;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Abandonar sesión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La sesión se cerrará, pero conservaremos todo lo que ya has realizado. ¿Cuál es el motivo?',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WorkoutAbandonmentReason.values
                    .map(
                      (reason) => ChoiceChip(
                        label: Text(workoutAbandonmentReasonLabel(reason)),
                        selected: selected == reason,
                        onSelected: (_) {
                          setDialogState(() => selected = reason);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Seguir entrenando'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Confirmar abandono'),
            ),
          ],
        ),
      );
    },
  );
  if (reason == null || !context.mounted) return false;
  final cubit = context.read<ActiveWorkoutCubit>();
  await cubit.abandon(reason);
  // El router solo permite salir tras el cierre confirmado o encolado.
  // Un fallo o la cancelación del motivo mantiene la pantalla y su borrador.
  return cubit.state.status == ActiveWorkoutStatus.abandoned;
}

class _AmrapCard extends StatefulWidget {
  const _AmrapCard({
    super.key,
    required this.executionId,
    required this.sets,
    required this.timerStore,
    required this.cueService,
    required this.saving,
    required this.onComplete,
  });

  final String executionId;
  final List<WorkoutExecutionSet> sets;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;
  final bool saving;
  final ValueChanged<WorkoutAmrapResultInput> onComplete;

  @override
  State<_AmrapCard> createState() => _AmrapCardState();
}

class _AmrapCardState extends State<_AmrapCard> {
  final _formKey = GlobalKey<FormState>();
  final _roundsController = TextEditingController(text: '0');
  final _partialRepsController = TextEditingController(text: '0');
  int? _partialItemOrder;

  WorkoutExecutionSet get first => widget.sets.first;

  @override
  void dispose() {
    _roundsController.dispose();
    _partialRepsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final partialReps = int.parse(_partialRepsController.text);
    widget.onComplete(
      WorkoutAmrapResultInput(
        executionId: widget.executionId,
        blockOrder: first.blockOrder,
        completedRounds: int.parse(_roundsController.text),
        partialItemOrder: partialReps == 0
            ? null
            : (_partialItemOrder ?? widget.sets.first.itemOrder),
        partialReps: partialReps,
      ),
    );
  }

  String? _validatePartialReps(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) {
      return 'Introduce un número entero válido';
    }
    if (parsed == 0) return null;
    final selectedOrder = _partialItemOrder ?? widget.sets.first.itemOrder;
    final target = widget.sets
        .firstWhere((set) => set.itemOrder == selectedOrder)
        .targetReps;
    if (target != null && parsed >= target) {
      return 'Si completas el objetivo, cuenta una vuelta o pasa al siguiente ejercicio';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final seconds = first.blockTimeCapSeconds ?? 600;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                first.blockName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFF8A50),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AMRAP',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              for (final set in widget.sets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '${set.itemOrder + 1}. ${set.exerciseName} · ${set.targetReps} reps',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              const SizedBox(height: 18),
              WorkoutSetCountdown(
                targetSeconds: seconds,
                title: 'RELOJ GLOBAL AMRAP',
                timerId: '${widget.executionId}:amrap:${first.blockOrder}',
                timerStore: widget.timerStore,
                enabled: !widget.saving,
                onElapsedChanged: (_) {},
                onPreparationTick: () => unawaited(
                  widget.cueService.signal(WorkoutCue.preparationTick),
                ),
                onStarted: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.workStarted)),
                onHalfway: () =>
                    unawaited(widget.cueService.signal(WorkoutCue.halfway)),
                onTenSecondsRemaining: () => unawaited(
                  widget.cueService.signal(WorkoutCue.tenSecondsRemaining),
                ),
                onEndingTick: (_) => unawaited(
                  widget.cueService.signal(WorkoutCue.workEndingTick),
                ),
                onFinished: () => unawaited(
                  widget.cueService.signal(WorkoutCue.workFinished),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Resultado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roundsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Vueltas completas',
                ),
                validator: _nonNegativeIntegerValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _partialItemOrder,
                decoration: const InputDecoration(
                  labelText: 'Último ejercicio parcial (opcional)',
                ),
                items: widget.sets
                    .map(
                      (set) => DropdownMenuItem(
                        value: set.itemOrder,
                        child: Text(set.exerciseName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.saving
                    ? null
                    : (value) => setState(() => _partialItemOrder = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _partialRepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Repeticiones parciales',
                ),
                validator: _validatePartialReps,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.saving ? 'Guardando…' : 'Guardar resultado AMRAP',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _nonNegativeIntegerValidator(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed < 0
      ? 'Introduce un número entero válido'
      : null;
}

class _PendingSyncBanner extends StatelessWidget {
  const _PendingSyncBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A2B16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Color(0xFFFFB36B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'cambio guardado' : 'cambios guardados'} '
                'en este dispositivo. Se sincronizará${count == 1 ? '' : 'n'} '
                'cuando vuelva la conexión.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({
    required this.rpe,
    required this.notesController,
    required this.averageHeartRateController,
    required this.maxHeartRateController,
    required this.showHeartRate,
    required this.saving,
    required this.onChanged,
    required this.onFinish,
  });

  final int? rpe;
  final TextEditingController notesController;
  final TextEditingController averageHeartRateController;
  final TextEditingController maxHeartRateController;
  final bool showHeartRate;
  final bool saving;
  final ValueChanged<int> onChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 42,
              color: Color(0xFFFF8A50),
            ),
            const SizedBox(height: 12),
            const Text(
              'Todas las series completadas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text(
              rpe == null
                  ? 'Selecciona el esfuerzo global (obligatorio)'
                  : 'Esfuerzo global · RPE $rpe',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var value = 1; value <= 10; value++)
                  ChoiceChip(
                    label: Text('$value'),
                    selected: rpe == value,
                    onSelected: saving ? null : (_) => onChanged(value),
                  ),
              ],
            ),
            if (showHeartRate) ...[
              const SizedBox(height: 8),
              const Text(
                'Frecuencia cardíaca (opcional)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: averageHeartRateController,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'FC media',
                        suffixText: 'ppm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxHeartRateController,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'FC máxima',
                        suffixText: 'ppm',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              enabled: !saving,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: '¿Cómo te has sentido? (opcional)',
                hintText:
                    'Técnica, molestias, energía o cualquier detalle útil.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: saving ? null : onFinish,
              child: Text(saving ? 'Guardando…' : 'Finalizar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Completed extends StatelessWidget {
  const _Completed({required this.execution, required this.pendingSyncCount});

  final WorkoutExecution execution;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final isRunning =
        execution.sets.isNotEmpty &&
        execution.sets.every(
          (set) => set.blockFormat == WorkoutBlockFormat.running,
        );
    return WorkoutClosureLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingSyncCount > 0) ...[
            _PendingSyncBanner(count: pendingSyncCount),
            const SizedBox(height: 18),
          ],
          const Icon(
            Icons.check_circle_rounded,
            size: 68,
            color: Color(0xFFFF8A50),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sesión completada',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${execution.completedSetCount} completadas'
            '${execution.skippedSetCount == 0 ? '' : ' · ${execution.skippedSetCount} omitidas'}'
            ' · RPE ${execution.finalRpe ?? '-'}',
            style: const TextStyle(color: Colors.white60),
          ),
          if (isRunning) ...[
            const SizedBox(height: 8),
            Text(
              runningAssessmentLabel(assessRunningExecution(execution.sets)),
              style: const TextStyle(
                color: Color(0xFFFFA06F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (execution.averageHeartRateBpm != null ||
              execution.maxHeartRateBpm != null) ...[
            const SizedBox(height: 8),
            Text(
              'FC ${execution.averageHeartRateBpm ?? '-'} media · '
              '${execution.maxHeartRateBpm ?? '-'} máxima',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
          if (execution.notes case final notes?) ...[
            const SizedBox(height: 14),
            Text(
              '“$notes”',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 22),
          WorkoutClosureActions(
            executionId: execution.id,
            pendingSyncCount: pendingSyncCount,
          ),
        ],
      ),
    );
  }
}

class _Abandoned extends StatelessWidget {
  const _Abandoned({required this.execution, required this.pendingSyncCount});

  final WorkoutExecution execution;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final reason = execution.abandonmentReason;
    return WorkoutClosureLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingSyncCount > 0) ...[
            _PendingSyncBanner(count: pendingSyncCount),
            const SizedBox(height: 18),
          ],
          const Icon(Icons.flag_outlined, size: 68, color: Color(0xFFFFA06F)),
          const SizedBox(height: 16),
          const Text(
            'Sesión cerrada',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${execution.completedSetCount} '
            '${execution.completedSetCount == 1 ? 'serie completada' : 'series completadas'}'
            '${reason == null ? '' : ' · ${workoutAbandonmentReasonLabel(reason)}'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lo realizado se conserva para tu historial.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          WorkoutClosureActions(
            executionId: execution.id,
            pendingSyncCount: pendingSyncCount,
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
