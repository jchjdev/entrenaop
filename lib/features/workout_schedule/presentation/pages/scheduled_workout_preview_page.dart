import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:workout_core/workout_template.dart';

import '../../../../core/navigation/workflow_exit_guard.dart';
import '../../../../core/presentation/app_dates.dart';
import '../../../../core/presentation/widgets/entrena_card.dart';
import '../../../exercises/domain/entities/exercise_entity.dart';
import '../../../exercises/presentation/widgets/exercise_detail_sheet.dart';
import '../../../workouts/domain/services/phone_running.dart';
import '../../../workouts/presentation/widgets/phone_run_panel.dart';
import '../../../workouts/presentation/pages/workout_preview_page.dart';
import '../../../workouts/presentation/open_workout_prompt.dart';
import '../../../pro/domain/pro_offer.dart';
import '../../domain/entities/scheduled_workout.dart';
import '../../domain/entities/scheduled_workout_preview.dart';
import '../bloc/scheduled_workout_preview_cubit.dart';

class ScheduledWorkoutPreviewPage extends StatelessWidget {
  const ScheduledWorkoutPreviewPage({
    required this.routeBase,
    this.getExercise,
    this.initialDate,
    super.key,
  });

  final String routeBase;
  final Future<ExerciseEntity?> Function(String)? getExercise;
  final DateTime? initialDate;

  void _showExercise(BuildContext context, WorkoutItem item) {
    final exercise = getExercise!(item.exerciseId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FutureBuilder<ExerciseEntity?>(
        future: exercise,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final details = snapshot.data;
          if (details == null) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se ha podido abrir la ficha del ejercicio.'),
              ),
            );
          }
          return ExerciseDetailSheet(
            name: details.name,
            description: details.description,
            imageUrl: details.thumbnailUrl,
            videoUrl: details.videoUrl,
            muscleGroups: details.muscleGroups,
            equipment: details.equipment,
            sessionInstructions: item.notes,
          );
        },
      ),
    );
  }

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
  Widget build(BuildContext context) =>
      BlocConsumer<ScheduledWorkoutPreviewCubit, ScheduledWorkoutPreviewState>(
        listenWhen: (previous, current) =>
            current.executionId != null &&
            current.executionId != previous.executionId,
        listener: (context, state) async {
          await context.push(
            '$routeBase/active/${state.executionId}',
            extra: state.startWithPhone ? true : null,
          );
          if (context.mounted) {
            await context.read<ScheduledWorkoutPreviewCubit>().load();
          }
        },
        builder: _buildPreview,
      );

  Widget _buildPreview(
    BuildContext context,
    ScheduledWorkoutPreviewState state,
  ) {
    final showsPhoneActions = _showsPhoneActions(state);
    // En pantallas pequeñas o con letra grande, ambas acciones caben al
    // desplazarse con la ficha, sin quitarle todo el alto a su contenido.
    final inlineActions =
        showsPhoneActions &&
        (MediaQuery.sizeOf(context).height < 600 ||
            MediaQuery.textScalerOf(context).scale(16) > 20);
    return WorkflowDraftGuard(
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
              onExercisePressed:
                  getExercise != null &&
                      preview.scheduled.source ==
                          ScheduledWorkoutSource.coach &&
                      preview.scheduled.status == ScheduledWorkoutStatus.planned
                  ? (item) => _showExercise(context, item)
                  : null,
              leading: _AssignmentSummary(preview: preview),
              showRecordingInstructions: !showsPhoneActions,
              trailing: inlineActions
                  ? _PreviewAction(state: state, inline: true)
                  : null,
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
          bottomNavigationBar: state.preview == null || inlineActions
              ? null
              : _PreviewAction(state: state),
        ),
      ),
    );
  }
}

bool _showsPhoneActions(ScheduledWorkoutPreviewState state) {
  final preview = state.preview;
  return preview != null &&
      preview.canStart &&
      !preview.proRequired &&
      !state.refreshRequired &&
      phoneRunSupported &&
      isContinuousPhoneRun(preview.workout);
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
  const _PreviewAction({required this.state, this.inline = false});
  final ScheduledWorkoutPreviewState state;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final preview = state.preview!;
    final cubit = context.read<ScheduledWorkoutPreviewCubit>();
    final resuming =
        preview.scheduled.status == ScheduledWorkoutStatus.inProgress;
    final canRecordWithPhone = _showsPhoneActions(state);
    return Material(
      color: inline
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      elevation: inline ? 0 : 8,
      child: SafeArea(
        top: false,
        bottom: !inline,
        minimum: inline
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                ] else if (preview.canStart) ...[
                  if (canRecordWithPhone && state.message == null) ...[
                    Text(
                      'Si registras manualmente, anota el resultado al terminar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                          : canRecordWithPhone
                          ? 'Registrar manualmente'
                          : resuming
                          ? 'Continuar entrenamiento'
                          : 'Comenzar entrenamiento',
                    ),
                  ),
                  if (canRecordWithPhone) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: state.canStart
                          ? () => startWithOpenWorkoutPrompt(
                              context,
                              () => cubit.start(withPhone: true),
                            )
                          : null,
                      icon: const Icon(Icons.gps_fixed_rounded),
                      label: Text(
                        resuming
                            ? 'Continuar con el móvil'
                            : 'Empezar con el móvil',
                      ),
                    ),
                  ],
                ] else if (preview.hasResult)
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
