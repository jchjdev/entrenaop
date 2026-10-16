import 'workout_amrap_review.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/dismiss_keyboard.dart';
import '../../../exercises/domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/services/workout_amrap_draft_store.dart';
import '../../domain/services/workout_cue_service.dart';
import '../../domain/services/workout_timer_store.dart';
import '../bloc/active_workout_cubit.dart';
import 'workout_amrap_sequence.dart';
import 'workout_execution_layout.dart';
import 'workout_execution_labels.dart';
import 'workout_exercise_technique.dart';
import 'workout_set_countdown.dart';

class WorkoutAmrapEntry extends StatelessWidget {
  const WorkoutAmrapEntry({
    super.key,
    required this.executionId,
    required this.sets,
    required this.draft,
    required this.exercises,
    required this.timerStore,
    required this.cueService,
    required this.saving,
    required this.records,
    required this.onRoundsChanged,
    required this.onComplete,
    this.errorMessage,
  });

  final String executionId;
  final String? errorMessage;
  final List<WorkoutExecutionSet> sets;
  final WorkoutAmrapDraft draft;
  final Map<String, ExerciseEntity> exercises;
  final WorkoutTimerStore timerStore;
  final WorkoutCueService cueService;
  final bool saving;
  final Widget records;
  final Future<void> Function(int delta) onRoundsChanged;
  final Future<bool> Function(WorkoutAmrapResultInput) onComplete;

  @override
  Widget build(BuildContext context) {
    final first = sets.first;
    final rounds = int.tryParse(draft.rounds);
    final roundsLabel = rounds == null || rounds < 0 || rounds > 2147483647
        ? 'Revisar vueltas'
        : '$rounds ${rounds == 1 ? 'vuelta completa' : 'vueltas completas'}';
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${first.blockName} · AMRAP · ${workoutClock(first.blockTimeCapSeconds ?? 600)} min',
            style: const TextStyle(
              color: Color(0xFFFFA06F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          WorkoutSetCountdown(
            key: ValueKey('amrap-clock-${first.blockOrder}'),
            compact: true,
            inlineControls: true,
            targetSeconds: first.blockTimeCapSeconds ?? 600,
            timerId: '$executionId:amrap:${first.blockOrder}',
            timerStore: timerStore,
            enabled: !saving,
            onElapsedChanged: (_) {},
            onPreparationTick: () =>
                unawaited(cueService.signal(WorkoutCue.preparationTick)),
            onStarted: () =>
                unawaited(cueService.signal(WorkoutCue.workStarted)),
            onHalfway: () => unawaited(cueService.signal(WorkoutCue.halfway)),
            onTenSecondsRemaining: () =>
                unawaited(cueService.signal(WorkoutCue.tenSecondsRemaining)),
            onEndingTick: (_) =>
                unawaited(cueService.signal(WorkoutCue.workEndingTick)),
            onFinished: () =>
                unawaited(cueService.signal(WorkoutCue.workFinished)),
          ),
        ],
      ),
    );
    final sequence = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'En cada vuelta',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        for (final set in sets)
          WorkoutAmrapExerciseTile(
            set: set,
            imageUrl: exercises[set.exerciseId]?.thumbnailUrl,
            onTap: () => showWorkoutTechnique(context, set),
          ),
      ],
    );
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final add = OutlinedButton.icon(
              onPressed: saving ? null : () => onRoundsChanged(1),
              icon: const Icon(Icons.add_rounded),
              label: const Text('1 vuelta'),
            );
            final counter = Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Restar una vuelta',
                  onPressed: saving || (int.tryParse(draft.rounds) ?? 0) == 0
                      ? null
                      : () => onRoundsChanged(-1),
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      roundsLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 10), add],
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                counter,
                if (stacked) ...[const SizedBox(height: 8), add],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: saving ? null : () => _review(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Terminar AMRAP',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            records,
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Con poco alto o texto ampliado se desplaza también el reloj, sin
        // sacrificar accesibilidad para mantener un encabezado rígido.
        final pinned =
            constraints.maxHeight >= 560 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19;
        return WorkoutExecutionFrame(
          header: pinned ? header : null,
          actions: actions,
          child: pinned
              ? sequence
              : Column(
                  children: [header, const SizedBox(height: 12), sequence],
                ),
        );
      },
    );
  }

  Future<void> _review(BuildContext context) async {
    dismissKeyboard();
    final cubit = context.read<ActiveWorkoutCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: WorkoutAmrapReview(
          executionId: executionId,
          sets: sets,
          onComplete: onComplete,
        ),
      ),
    );
    dismissKeyboard();
  }
}
