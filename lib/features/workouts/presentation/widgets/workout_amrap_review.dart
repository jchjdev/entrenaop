import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/dismiss_keyboard.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_amrap_draft.dart';
import '../bloc/active_workout_cubit.dart';
import '../bloc/active_workout_state.dart';
import 'workout_amrap_sequence.dart';
import 'workout_execution_layout.dart';
import 'workout_execution_labels.dart';

class WorkoutAmrapReview extends StatefulWidget {
  const WorkoutAmrapReview({
    super.key,
    required this.executionId,
    required this.sets,
    required this.onComplete,
  });
  final String executionId;
  final List<WorkoutExecutionSet> sets;
  final Future<bool> Function(WorkoutAmrapResultInput) onComplete;
  @override
  State<WorkoutAmrapReview> createState() => _WorkoutAmrapReviewState();
}

class _WorkoutAmrapReviewState extends State<WorkoutAmrapReview> {
  String? _validation;
  int get _blockOrder => widget.sets.first.blockOrder;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
    builder: (context, state) {
      final cubit = context.read<ActiveWorkoutCubit>();
      final draft = state.amrapDrafts[_blockOrder] ?? const WorkoutAmrapDraft();
      final saving = state.status == ActiveWorkoutStatus.saving;
      void update(WorkoutAmrapDraft value) {
        setState(() => _validation = null);
        unawaited(cubit.updateAmrapDraft(_blockOrder, value));
      }

      final media = MediaQuery.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: (media.size.height * .87 - media.viewInsets.bottom).clamp(
              180,
              media.size.height,
            ),
            child: WorkoutExecutionFrame(
              actions: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_validation ?? state.errorMessage
                      case final String message)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final error = draft.validate(widget.sets);
                            if (error != null) {
                              setState(() => _validation = error);
                              return;
                            }
                            dismissKeyboard();
                            final saved = await widget.onComplete(
                              draft.toResult(
                                executionId: widget.executionId,
                                blockOrder: _blockOrder,
                                sequence: widget.sets,
                              ),
                            );
                            if (context.mounted && saved) {
                              Navigator.pop(context);
                            }
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(saving ? 'Guardando…' : 'Guardar resultado'),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Resultado AMRAP',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Volver al AMRAP',
                        onPressed: saving
                            ? null
                            : () {
                                dismissKeyboard();
                                Navigator.pop(context);
                              },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('amrap-rounds-$_blockOrder'),
                    initialValue: draft.rounds,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => dismissKeyboard(),
                    decoration: const InputDecoration(
                      labelText: 'Vueltas completas',
                    ),
                    onChanged: (value) => update(draft.copyWith(rounds: value)),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('¿Empezaste otra vuelta?'),
                    value: draft.hasPartial,
                    onChanged: saving
                        ? null
                        : (value) => update(
                            draft.copyWith(
                              hasPartial: value,
                              partialItemOrder:
                                  draft.partialItemOrder ??
                                  widget.sets.first.itemOrder,
                            ),
                          ),
                  ),
                  if (draft.hasPartial) ...[
                    const Text(
                      '¿Dónde terminaste?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Los ejercicios anteriores de esta vuelta cuentan como completos. Si acabaste justo antes de este, indica 0 repeticiones.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    for (final set in widget.sets)
                      WorkoutAmrapExerciseTile(
                        set: set,
                        imageUrl: state.exercises[set.exerciseId]?.thumbnailUrl,
                        selected: draft.partialItemOrder == set.itemOrder,
                        onTap: () {
                          if (!saving &&
                              draft.partialItemOrder != set.itemOrder) {
                            update(
                              draft.copyWith(
                                partialItemOrder: set.itemOrder,
                                partialReps: '0',
                              ),
                            );
                          }
                        },
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('amrap-reps-${draft.partialItemOrder}'),
                      initialValue: draft.partialReps,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => dismissKeyboard(),
                      decoration: const InputDecoration(
                        labelText: 'Repeticiones realizadas en ese ejercicio',
                      ),
                      onChanged: (value) =>
                          update(draft.copyWith(partialReps: value)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    workoutAmrapDraftSummary(draft, widget.sets),
                    style: const TextStyle(
                      color: Color(0xFFFFA06F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
