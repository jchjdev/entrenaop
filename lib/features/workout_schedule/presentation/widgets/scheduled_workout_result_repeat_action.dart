import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../pro/domain/pro_access.dart';
import '../../../workouts/presentation/open_workout_prompt.dart';
import '../../domain/entities/scheduled_workout.dart';
import '../../domain/usecases/workout_schedule_usecases.dart';
import 'scheduled_workout_repeat_button.dart';

class ScheduledWorkoutResultRepeatAction extends StatefulWidget {
  const ScheduledWorkoutResultRepeatAction({
    required this.executionId,
    required this.getScheduledWorkout,
    required this.repeatWorkout,
    super.key,
  });

  final String executionId;
  final GetRepeatableScheduledWorkoutUseCase getScheduledWorkout;
  final RepeatScheduledWorkoutUseCase repeatWorkout;

  @override
  State<ScheduledWorkoutResultRepeatAction> createState() =>
      _ScheduledWorkoutResultRepeatActionState();
}

class _ScheduledWorkoutResultRepeatActionState
    extends State<ScheduledWorkoutResultRepeatAction> {
  late Future<ScheduledWorkout?> _scheduledWorkout;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scheduledWorkout = widget.getScheduledWorkout(widget.executionId);
  }

  Future<void> _repeat(ScheduledWorkout item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startWithOpenWorkoutPrompt(context, () async {
        final executionId = await widget.repeatWorkout(item.id);
        if (mounted) {
          await context.push(
            '/plan/week/active/${Uri.encodeComponent(executionId)}',
          );
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ProAccessDenied ? error.message : 'No hemos podido repetir esta pauta. Comprueba que sigue disponible.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _scheduledWorkout = widget.getScheduledWorkout(widget.executionId);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScheduledWorkout?>(
    future: _scheduledWorkout,
    builder: (context, snapshot) {
      final item = snapshot.data;
      if (item == null) return const SizedBox.shrink();
      return Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                child: ScheduledWorkoutRepeatButton(
                  resuming: item.repeatExecutionId != null,
                  onPressed:
                      _busy || snapshot.connectionState != ConnectionState.done
                      ? null
                      : () => _repeat(item),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
