import 'package:flutter/material.dart';

class ScheduledWorkoutRepeatButton extends StatelessWidget {
  const ScheduledWorkoutRepeatButton({
    required this.resuming,
    required this.onPressed,
    super.key,
  });

  final bool resuming;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(resuming ? Icons.play_arrow_rounded : Icons.replay_rounded),
    label: Text(resuming ? 'Continuar repetición' : 'Repetir entrenamiento'),
  );
}
