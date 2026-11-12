import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/workout_template.dart';

import '../../../../core/navigation/workflow_exit_guard.dart';
import '../../../../core/presentation/app_dates.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../workouts/presentation/pages/workout_preview_page.dart';
import '../../../workouts/presentation/open_workout_prompt.dart';
import '../../../pro/domain/pro_offer.dart';
import '../../domain/entities/scheduled_workout.dart';
import '../../domain/entities/scheduled_workout_preview.dart';
import '../bloc/scheduled_workout_preview_cubit.dart';

class ScheduledWorkoutPreviewPage extends StatelessWidget {
  const ScheduledWorkoutPreviewPage({
    required this.routeBase,
    this.initialDate,
    super.key,
  });

  final String routeBase;
  final DateTime? initialDate;

  void _back(BuildContext context, ScheduledWorkoutPreviewState state) {
    if (context.read<ScheduledWorkoutPreviewCubit>().state.status ==
        ScheduledWorkoutPreviewStatus.starting) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    final date =
        initialDate ?? state.preview?.scheduled.scheduledDate ?? DateTime.now();
    context.go('/plan/week?date=${DateFormat('yyyy-MM-dd').format(date)}');
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ScheduledWorkoutPreviewCubit, ScheduledWorkoutPreviewState>(
    listenWhen: (previous, current) =>
        current.executionId != null &&
        current.executionId != previous.executionId,
    listener: (context, state) async {
      await context.push('$routeBase/active/${state.executionId}');
      if (context.mounted) {
        await context.read<ScheduledWorkoutPreviewCubit>().load();
      }
    },
    builder: (context, state) => WorkflowDraftGuard(
      hasUnsavedChanges: () => false,
      isBusy: () =>
          context.read<ScheduledWorkoutPreviewCubit>().state.status ==
          ScheduledWorkoutPreviewStatus.starting,
      child: PopScope(
        canPop: state.status != ScheduledWorkoutPreviewStatus.starting,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Entrenamiento'),
            leading: BackButton(onPressed: () => _back(context, state)),
          ),
          body: switch (state.preview) {
            final preview? => WorkoutPreviewContent(
              key: PageStorageKey(
                'scheduled-preview-${preview.scheduled.id}-${preview.revision}',
              ),
              workout: preview.workout,
              thumbnails: const {},
              leading: _AssignmentSummary(preview: preview),
            ),
            null => Center(
              child:
                  state.busy ||
                      state.status == ScheduledWorkoutPreviewStatus.initial
                  ? const CircularProgressIndicator()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message ??
                                'No hemos podido consultar este entrenamiento.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: context
                                .read<ScheduledWorkoutPreviewCubit>()
                                .load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
            ),
          },
          bottomNavigationBar: state.preview == null
              ? null
              : _PreviewAction(state: state),
        ),
      ),
    ),
  );
}

class _AssignmentSummary extends StatelessWidget {
  const _AssignmentSummary({required this.preview});
  final ScheduledWorkoutPreview preview;

  @override
  Widget build(BuildContext context) {
    final item = preview.scheduled;
    final date = formatAppDate(item.scheduledDate);
    final time = item.scheduledTime;
    return EntrenaCard(
      tone: EntrenaCardTone.quiet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pautado · $date${time == null ? '' : ' · ${time.substring(0, 5)}'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (item.isSelfAssigned)
            const Text('Para mí · pautado desde Trainer')
          else if (item.coachName case final name?)
            Text('Preparador: $name')
          else
            Text(switch (item.source) {
              ScheduledWorkoutSource.coach => 'Tu preparador',
              ScheduledWorkoutSource.algorithm =>
                'Programa automático EntrenaOP',
              ScheduledWorkoutSource.preparation => 'Tu preparación',
              ScheduledWorkoutSource.library => 'Desde tu biblioteca',
              ScheduledWorkoutSource.user => 'Tu entrenamiento personal',
            }),
          if (item.coachNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(item.coachNote!),
          ],
          if (preview.workout.blocks.any(
            (block) => block.format == WorkoutBlockFormat.running,
          )) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  context.read<ScheduledWorkoutPreviewCubit>().state.status ==
                      ScheduledWorkoutPreviewStatus.starting
                  ? null
                  : () => context.push('/tools/running-pace-calculator'),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Calcular ritmos y parciales'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction({required this.state});
  final ScheduledWorkoutPreviewState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final cubit = context.read<ScheduledWorkoutPreviewCubit>();
    final resuming =
        preview.scheduled.status == ScheduledWorkoutStatus.inProgress;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.message case final message?) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                ],
                if (state.refreshRequired)
                  FilledButton(
                    onPressed: state.busy ? null : cubit.load,
                    child: Text(state.busy ? 'Actualizando…' : 'Reintentar'),
                  )
                else if (preview.proRequired) ...[
                  const Text(
                    'Activa Pro para entrenar con este plan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push(
                        ProOfferContext(
                          goalId: preview.scheduled.preparationGoalId,
                        ).location(),
                      );
                      if (context.mounted) cubit.load();
                    },
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: const Text('Ver Pro'),
                  ),
                  TextButton(
                    onPressed: state.busy ? null : cubit.load,
                    child: const Text('Actualizar acceso'),
                  ),
                ] else if (preview.canStart)
                  FilledButton.icon(
                    key: const ValueKey('scheduled-preview-start'),
                    onPressed: state.canStart
                        ? () => startWithOpenWorkoutPrompt(context, cubit.start)
                        : null,
                    icon: state.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      state.busy
                          ? 'Preparando entrenamiento…'
                          : resuming
                          ? 'Continuar entrenamiento'
                          : 'Comenzar entrenamiento',
                    ),
                  )
                else if (preview.hasResult)
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/assessment/history/workouts/${preview.scheduled.executionId}',
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ver resultado'),
                  )
                else
                  const Text(
                    'Este entrenamiento ya no está pendiente.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
